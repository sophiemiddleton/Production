#!/usr/bin/bash
# Generate fcl files for BeamToVD1809.fcl
# Generates two sets of fcl files found in directories 1809_00X
# Stores the generated seeds in directory BeamToVD1809Seeds
# Pawel Plesniak

# $1 is the production (ie MDC2020)
# $2 is the input production version
# $3 is the output production version
# $4 is the number of events per job
# $5 is the number of jobs

# Validate the number of arguments
if [[ ${5} == "" ]]; then
  echo "Missing arguments!"
  exit 1
fi


# Generate the dataset list for electrons
muStopDataset=sim.mu2e.TargetStopsCat.$1$2.art
echo $eleDataset
if [ -f EleBeamCat.txt ]; then
    rm -f TargetStopsCat.txt
fi
# Generate a list of all the staged EleBeamCat files and count the events
samweb list-file-locations --schema=root --defname="$muStopDataset"  | cut -f1 > TargetStopsCat.txt
nFiles=`samCountFiles.sh $muStopDataset`
nEvts=`samCountEvents.sh $muStopDataset`
nSkip=$((nEvts/nFiles))
echo "Target stops: found $nEvts events in $nFiles files, skipping max of $nSkip events per job"

# Write the base propagation script for electrons
if [ -f tmp.fcl ]; then
    rm -f tmp.fcl
fi
echo '#include "Production/JobConfig/pileup/STM/BeamToVD1809.fcl"' >> tmp.fcl
echo physics.filters.TargetStopResampler.mu2e.MaxEventsToSkip: ${nSkip} >> tmp.fcl

# Generate the electrons fcl files
generate_fcl --dsconf=$1$3 --dsowner=$USER --run-number=1206 --description=BeamToVD1809 --events-per-job=$4 --njobs=$5 \
  --embed tmp.fcl --auxinput=1:physics.filters.TargetStopResampler.fileNames:TargetStopsCat.txt 

# Write the files to the correct directories
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  rm -rf 1809_$dirname
  mv $dirname 1809_$dirname
 fi
done

# Save the seed file to a directory
seedDir="BeamToVD1809Seeds"
if [ ! -d $seedDir ]; then
  mkdir $seedDir
fi
mv seeds.$USER.BeamToVD*.$1$3.*.txt $seedDir

# Cleanup
echo "Removing produced files"
rm -f tmp.fcl
rm -f TargetStopsCat.txt
echo "Finished"

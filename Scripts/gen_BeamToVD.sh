#!/usr/bin/bash
# Generate fcl files for BeamToVD.fcl
# Generates two sets of fcl files found in directories Ele_00X and Mu_00X
# Stores the generated seeds in directory BeamToVDSeeds
# Pawel Plesniak

# $1 is the production (ie MDC2020)
# $2 is the input production version
# $3 is the output production version
# $4 is the number of events per job for electrons
# $5 is the number of jobs for electrons
# $6 is the number of events per job for muons
# $7 is the number of jobs for muons

# Validate the number of arguments
if [[ ${7} == "" ]]; then
  echo "Missing arguments!"
  return -1
fi


# Generate the dataset list for electrons
eleDataset=sim.mu2e.EleBeamCat.$1$2.art
echo $eleDataset
if [ -f EleBeamCat.txt ]; then
    rm -f EleBeamCat.txt
fi
# Generate a list of all the staged EleBeamCat files and count the events
samweb list-file-locations --schema=root --defname="$eleDataset"  | cut -f1 > EleBeamCat.txt
nEleFiles=`samCountFiles.sh $eleDataset`
nEleEvts=`samCountEvents.sh $eleDataset`
nEleSkip=$((nEleEvts/nEleFiles))
echo "Electrons: found $nEleEvts events in $nEleFiles files, skipping max of $nEleSkip events per job"

# Write the base propagation script for electrons
if [ -f tmp.fcl ]; then
    rm -f tmp.fcl
fi
echo '#include "Production/JobConfig/pileup/STM/BeamToVD.fcl"' >> tmp.fcl
echo physics.filters.beamResampler.mu2e.MaxEventsToSkip: ${nEleSkip} >> tmp.fcl

# Generate the electrons fcl files
generate_fcl --dsconf=$1$3 --dsowner=$USER --run-number=1204 --description=BeamToVDEle --events-per-job=$4 --njobs=$5 \
  --embed tmp.fcl --auxinput=1:physics.filters.beamResampler.fileNames:EleBeamCat.txt 

# Write the files to the correct directories
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  rm -rf Ele_$dirname
  mv $dirname Ele_$dirname
 fi
done
rm -f tmp.fcl


# Do the same thing but for MuBeamCat
# Generate the dataset list for muons
muDataset=sim.mu2e.MuBeamCat.$1$2.art
if [ -f MuBeamCat.txt ]; then
    rm -f MuBeamCat.txt
fi
# Generate a list of all the staged MuBeamCat files and count the events
samweb list-file-locations --schema=root --defname="$muDataset"  | cut -f1 > MuBeamCat.txt
nMuFiles=`samCountFiles.sh $muDataset`
nMuEvts=`samCountEvents.sh $muDataset`
nMuSkip=$((nMuEvts/nMuFiles))
echo "Muons: found $nMuEvts events in $nMuFiles files, skipping max of $nMuSkip events per job"

# Write the base propagation script for muons
echo '#include "Production/JobConfig/pileup/STM/BeamToVD.fcl"' >> tmp.fcl
echo physics.filters.beamResampler.mu2e.MaxEventsToSkip: ${nMuSkip} >> tmp.fcl
# Generate the electrons fcl files
generate_fcl --dsconf=$1$3 --dsowner=$USER --run-number=1205 --description=BeamToVDMu --events-per-job=$6 --njobs=$7 \
  --embed tmp.fcl --auxinput=1:physics.filters.beamResampler.fileNames:MuBeamCat.txt 
# Write the files to the correct directories
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  rm -rf Mu_$dirname
  mv $dirname Mu_$dirname
 fi
done

# Save the seed file to a directory
seedDir="BeamToVDSeeds"
if [ ! -d $seedDir ]; then
  mkdir $seedDir
fi
mv seeds.$USER.BeamToVD*.$1$3.*.txt $seedDir

# Cleanup
echo "Removing produced files"
rm -f EleBeamCat.txt
rm -f MuBeamCat.txt
rm -f tmp.fcl
echo "Finished"

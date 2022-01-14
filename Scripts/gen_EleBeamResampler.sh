#!/usr/bin/bash
#
# create a script for running the EleBeamResampler from an official dataset
#
# $1 is the production (ie MDC2020)
# $2 is the input production version
# $3 is the output production version
# $4 is the number of jobs
if [[ ${4} == "" ]]; then
  echo "Missing arguments!"
  return -1
fi

# create the input list
dataset=sim.mu2e.EleBeamCat.$1$2.art
samweb list-file-locations --schema=root --defname="$dataset"  | cut -f1 > EleBeamCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the elebeamresampler.fcl
rm elebeamresampler.fcl
echo '#include "Production/JobConfig/pileup/EleBeamResampler.fcl"' >> elebeamresampler.fcl
echo physics.filters.beamResampler.mu2e.MaxEventsToSkip: ${nskip} >> elebeamresampler.fcl
#
generate_fcl --dsconf=$1$3 --dsowner=brownd --run-number=1202 --description=EleBeamResampler --events-per-job=400000 --njobs=$4 \
  --embed elebeamresampler.fcl --auxinput=1:physics.filters.beamResampler.fileNames:EleBeamCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf EleBeamResampler_$dirname
  mv $dirname EleBeamResampler_$dirname
 fi
done


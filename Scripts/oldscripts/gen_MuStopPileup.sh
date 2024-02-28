#!/usr/bin/bash
#
# create a script for running the TargetStopResampler from an official dataset
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
dataset=sim.mu2e.TargetStopsCat.$1$2.art
samweb list-file-locations --schema=root --defname="$dataset"  | cut -f1 > TargetStopsCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the targetstopresampler.fcl
rm -f targetstopresampler.fcl
echo '#include "Production/JobConfig/pileup/MuStopPileup.fcl"' >> targetstopresampler.fcl
echo physics.filters.TargetStopResampler.mu2e.MaxEventsToSkip: ${nskip} >> targetstopresampler.fcl
#
generate_fcl --dsconf=$1$3 --dsowner=mu2e --run-number=1202 --description=TargetStopResampler --events-per-job=400000 --njobs=$4 \
  --embed targetstopresampler.fcl --auxinput=1:physics.filters.TargetStopResampler.fileNames:TargetStopsCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf TargetStopResampler_$dirname
  mv $dirname TargetStopResampler_$dirname
 fi
done


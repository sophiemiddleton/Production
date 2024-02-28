#!/usr/bin/bash
#
# create a script for running the PiBeamResampler from an official dataset
#
# $1 is the production (ie MDC2020)
# $2 is the input production version
# $3 is the output production version
# $4 is the number of jobs
# Written by Sophie Middleton
if [[ ${4} == "" ]]; then
  echo "Missing arguments!"
  return -1
fi

# create the input list
dataset=sim.mu2e.PiInfiniteBeamCat.$1$2.art
samweb list-file-locations --schema=root --defname="$dataset"  | cut -f1 > PiInfiniteBeamCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the pibeamresampler.fcl
rm -f pibeamresampler.fcl
echo '#include "Production/JobConfig/pileup/PiBeamResampler.fcl"' >> pibeamresampler.fcl
echo physics.filters.beamResampler.mu2e.MaxEventsToSkip: ${nskip} >> pibeamresampler.fcl
#
generate_fcl --dsconf=$1$3 --dsowner=sophie --run-number=1202 --description=PiBeamResampler --events-per-job=400000 --njobs=$4 --embed pibeamresampler.fcl --auxinput=1:physics.filters.beamResampler.fileNames:PiInfiniteBeamCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf PiInfiniteBeamResampler_$dirname
  mv $dirname PiInfiniteBeamResampler_$dirname
 fi
done

#!/usr/bin/bash
#
# create a script for running the NeutralsResampler from an official dataset
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
dataset=sim.mu2e.NeutralsCat.$1$2.art
samweb list-file-locations --schema=root --defname="$dataset"  | cut -f1 > NeutralsCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the neutralsresampler.fcl
rm -f neutralsresampler.fcl
echo '#include "Production/JobConfig/pileup/NeutralsResampler.fcl"' >> neutralsresampler.fcl
echo physics.filters.neutralsResampler.mu2e.MaxEventsToSkip: ${nskip} >> neutralsresampler.fcl
#
generate_fcl --dsconf=$1$3 --dsowner=mu2e --run-number=1202 --description=NeutralsResampler --events-per-job=400000 --njobs=$4 \
  --embed neutralsresampler.fcl --auxinput=1:physics.filters.neutralsResampler.fileNames:NeutralsCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf NeutralsResampler_$dirname
  mv $dirname NeutralsResampler_$dirname
 fi
done


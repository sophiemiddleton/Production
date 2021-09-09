#!/usr/bin/bash
# create the input list
dataset=sim.mu2e.MuminusTargetStopsCat.MDC2020$1.art
samListLocations --defname="$dataset" > MuminusTargetStopsCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template fcl
rm template.fcl
echo '#include "Production/JobConfig/pileup/MuStopPileup.fcl"' >> template.fcl
echo physics.filters.TargetStopResampler.mu2e.MaxEventsToSkip: ${nskip} >> template.fcl
#
generate_fcl --dsconf=MDC2020$1 --dsowner=brownd --run-number=1205 --description=MuStopPileup --events-per-job=200000 --njobs=100 \
--embed template.fcl --auxinput=1:physics.filters.TargetStopResampler.fileNames:MuminusTargetStopsCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf MuStopPileupi$1_$dirname
  mv $dirname MuStopPileup$1_$dirname
 fi
done


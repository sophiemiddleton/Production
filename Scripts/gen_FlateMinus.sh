#!/usr/bin/bash
# create the input list
dataset=sim.mu2e.MuminusStopsCat.MDC2020$1.art
samListLocations --defname="$dataset" > MuminusStopsCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template fcl
rm template.fcl
echo '#include "Production/JobConfig/primary/FlateMinus.fcl"' >> template.fcl
echo physics.filters.TargetStopResampler.mu2e.MaxEventsToSkip: ${nskip} >> template.fcl
echo physics.producers.generate.startMom : 75 >> template.fcl
echo physics.producers.generate.endMom : 110 >> template.fcl
#
generate_fcl --dsconf=MDC2020$1 --dsowner=brownd --run-number=1210 --description=FlateMinus --events-per-job=4000 --njobs=100 \
--embed template.fcl --auxinput=1:physics.filters.TargetStopResampler.fileNames:MuminusStopsCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf FlateMinus$1_$dirname
  mv $dirname FlateMinus$1_$dirname
 fi
done


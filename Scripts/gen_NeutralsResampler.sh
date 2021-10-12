#!/usr/bin/bash
# create the input list
dataset=sim.mu2e.NeutralsCat.MDC2020$1.art
samListLocations --defname="$dataset" > NeutralsCat.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template fcl
rm template.fcl
echo '#include "Production/JobConfig/beam/NeutralsResampler.fcl"' >> template.fcl
echo physics.filters.neutralsResampler.mu2e.MaxEventsToSkip: ${nskip} >> template.fcl
#
generate_fcl --dsconf=MDC2020$1 --dsowner=brownd --run-number=1203 --description=NeutralsResampler --events-per-job=200000 --njobs=1000 \
--embed template.fcl --auxinput=1:physics.filters.neutralsResampler.fileNames:NeutralsCat.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf NeutralsResampler$1_$dirname
  mv $dirname NeutralsResampler$1_$dirname
 fi
done


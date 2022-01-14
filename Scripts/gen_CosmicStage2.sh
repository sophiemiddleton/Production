#!/usr/bin/bash
#
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
# $1 is the type of cosmic (CRY, CORSIKA, ...)
# $2 is the dataset description
# $3 is the campaign version of the input stage1 file
# $4 is the campaign version of the output stage2 file.
# $5 is the number of events/job
# $6 is the number of jobs
cosmic=$1
name=CosmicDSStops$cosmic.$2$3
conf=$2$4
eventsperjob=$5
njobs=$6
s2out=Cosmic$cosmic
#
rm stage2.fcl
samweb list-file-locations --schema=root --defname="sim.mu2e.${name}.art"  | cut -f1 > CosmicDSStops.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
echo "found $nfiles files with $nevts total events for sim.mu2e.$name.art for maxskip $nskip"
echo \#include \"Production/JobConfig/cosmic/S2Resampler${cosmic}.fcl\" >> stage2.fcl
echo physics.filters.CosmicResampler.mu2e.MaxEventsToSkip: ${nskip} >> stage2.fcl
generate_fcl --dsconf="$conf" --dsowner=mu2e --run-number=1202 --description="${s2out}" --embed stage2.fcl \
--events-per-job=${eventsperjob} --njobs=${njobs} \
--auxinput=1:physics.filters.CosmicResampler.fileNames:CosmicDSStops.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
  if test -d $dirname; then
    echo "found dir $dirname"
    rm -rf "${s2out}_$dirname"
    mv $dirname "${s2out}_$dirname"
  fi
done


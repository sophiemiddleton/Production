#!/usr/bin/bash
#
# create fcl for producing primaries from stopped particles
# this script requires mu2etools and dhtools be setup
#
# $1 is the primary
# $2 is the production (ie MDC2020)
# $3 is the stops production version
# $4 is the output primary production version
# $5 is the kind of input stops (Muminus, Muplus, IPAMuminus, IPAMuplus, Piminus, Piplus, or Cosmic)
# $6 is the number of jobs
# $7 is the number of events/job
# $8 is the pdgId of the particle to generate
# $9 is the startMom
# $10 is the endMom
# $11 (optional) is the name of the BField file

# e.g. source gen_Primary.sh CeEndpoint MDC2020 p v Muminus 1000 4000 -11 0 110 Offline/Mu2eG4/geom/bfgeom_reco_altDS11_helical_v01.txt

primary=$1
stopsconf=$2$3
primaryconf=$2$4
stype=$5
njobs=$6
eventsperjob=$7
pdg=$8
startMom=$9
endMom=${10}
bfield=${11} #FIXME, should always have to input this!


dataset=sim.mu2e.${stype}StopsCat.${stopsconf}.art

if [[ "${stype}" == "Muminus" ]] ||  [[ "${stype}" == "Muplus" ]]; then
  resampler=TargetStopResampler
elif [[ "${stype}" == "Piminus" ]] ||  [[ "${stype}" == "Piplus" ]]; then
  resampler=TargetPiStopResampler
elif [[ "${stype}" == "Cosmic" ]]; then
  dataset=sim.mu2e.${stype}DSStops${primary}.${stopsconf}.art
  resampler=${stype}Resampler
else
  resampler=${stype}StopResampler
fi
echo ${bfield} "is the field being used"
samweb list-file-locations --filter=dcache  --schema=root --defname="$dataset"  | cut -f1 > Stops.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template
rm -f primary.fcl
if [[ "${stype}" == "Cosmic" ]]; then
  echo "#include \"Production/JobConfig/cosmic/S2Resampler${primary}.fcl\"" >> primary.fcl
else
  echo "#include \"Production/JobConfig/primary/${primary}.fcl\"" >> primary.fcl
fi
echo physics.filters.${resampler}.mu2e.MaxEventsToSkip: ${nskip} >> primary.fcl
echo "services.GeometryService.bFieldFile : \"${bfield}\"" >> primary.fcl

if [[ "${stype}" == "FlatMuDaughter" ]]; then
  echo physics.producers.generate.pdgId: ${pdg}            >> primary.fcl
  echo physics.producers.generate.startMom: ${startMom}    >> primary.fcl
  echo physics.producers.generate.endMom: ${endMom}        >> primary.fcl
fi

#
# now generate the fcl
#
generate_fcl --dsconf=${primaryconf} --dsowner=mu2e --run-number=1202 --description=${primary} --events-per-job=${eventsperjob} --njobs=${njobs} \
  --embed primary.fcl --auxinput=1:physics.filters.${resampler}.fileNames:Stops.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf ${primary}\_$dirname
  mv $dirname ${primary}\_$dirname
  echo "moving $dirname to ${primary}_${dirname}"
 fi
done

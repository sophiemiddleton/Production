#!/usr/bin/bash
#
# create fcl for producing primaries from stopped particles
# this script requires mu2etools and dhtools be setup
#
#  source gen_Primary.sh CeEndpoint MDC2020 p v Muminus 1000 4000 -11 0 110 Offline/Mu2eG4/geom/bfgeom_reco_altDS11_helical_v01.txt

# The main input parameters needed for any campaign
PRIMARY="" # is the primary
PRIMARY_CAMPAIGN="" # production version followed by primary production version
STOPS_CAMPAIGN="" # is the production (ie MDC2020) followed by the stops production version 
TYPE="" # the kind of input stops (Muminus, Muplus, IPAMuminus, IPAMuplus, Piminus, Piplus, or Cosmic)
JOBS="" # is the number of jobs
EVENTS="" # is the number of events/job

# The following can be overridden if needed
PDG=11 #is the pdgId of the particle to generate
FIELD="Offline/Mu2eG4/geom/bfgeom_no_tsu_ps_v01.txt" #optional (for changing field map)
STARTMOM=0 # optional (for flat)
ENDMOM=110 # optional (for flat)
OWNER=mu2e
RUN=1202
DESC=${PRIMARY} # can override if more detailed tag is needed

# Function: Print a help message.
usage() {
  echo "Usage: $0 [ -p PRIMARY ] [ -v PRIMARY_CAMPAIGN ] [ -s STOPS_CAMPAIGN ] [-t TYPE][ -j JOBS ][ -e EVENTS ][ -pdg PDG ] [-f FIELD] [-smom STARTMOM] [-emom ENDMOM] [-o OWNER] [-r RUN] [ -d DESC ]" 1>&2 
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# Loop: Get the next option;
while getopts ":p:v:s:t:j:e:r:i:f:a:z:o:r:d:-:" options; do
  case "${options}" in                    
    p)                                    # If the option is p,
      PRIMARY=${OPTARG}                  # set $PRIMARY to specified value.
      ;;
    v)                                    
      PRIMARY_CAMPAIGN=${OPTARG}                   
      ;;
    s)                                    
      STOPS_CAMPAIGN=${OPTARG}                     
      ;;
    t)                                    
      TYPE=${OPTARG}                       
      ;;
    j)                                    
      JOBS=${OPTARG}                   
      ;;
    e)                                    
      EVENTS=${OPTARG}                      
      ;;
    i)                                   
      PDG=${OPTARG}                      
      ;;
    f)                                   
      FIELD=${OPTARG}                      
      ;;
    a)                                   
      STARTMOM=${OPTARG}                      
      ;;
    z)                                   
      ENDMOM=${OPTARG}                      
      ;;
    o)                                   
      OWNER=${OPTARG}                      
      ;;
    r)                                   
      RUN=${OPTARG}                      
      ;;
    d)                                   
      DESC=${OPTARG}                      
      ;;
    -)                                   
      case "${OPTARG}" in
                boo)
                    
                  echo "test " >&2;
                ;;                    
      esac;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Exit abnormally.
      ;;
    *)                                    # If unknown (any other) option:
      exit_abnormal                       # Exit abnormally.
      ;;
  esac
done

# Test: run a test to check the SimJob for this campaign verion exists TODO 
DIR=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${PRMARY_CAMPAIGN}
if [ -d "$DIR" ];
  then
    echo "$DIR directory exists."
  else
    echo "$DIR directory does not exist."
    exit 1
fi

dataset=sim.mu2e.${TYPE}StopsCat.${STOPS_CAMPAIGN}.art

if [[ "${TYPE}" == "Muminus" ]] ||  [[ "${TYPE}" == "Muplus" ]]; then
  resampler=TargetStopResampler
elif [[ "${TYPE}" == "Piminus" ]] ||  [[ "${TYPE}" == "Piplus" ]]; then
  resampler=TargetPiStopResampler
elif [[ "${TYPE}" == "Cosmic" ]]; then
  dataset=sim.mu2e.${TYPE}DSStops${PRIMARY}.${stopsconf}.art
  resampler=${TYPE}Resampler
else
  resampler=${TYPE}StopResampler
fi

echo "getting sam locations"
samweb list-file-locations --schema=root --defname="$dataset"  | cut -f1 > Stops.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template
rm -f primary.fcl
echo "adding primary fcl"
if [[ "${TYPE}" == "Cosmic" ]]; then
  echo "#include \"Production/JobConfig/cosmic/S2Resampler${PRIMARY}.fcl\"" >> primary.fcl
else
  echo "#include \"Production/JobConfig/primary/${PRIMARY}.fcl\"" >> primary.fcl
fi
echo physics.filters.${resampler}.mu2e.MaxEventsToSkip: ${nskip} >> primary.fcl
echo "services.GeometryService.bFieldFile : \"${FIELD}\"" >> primary.fcl
echo "finsihed primary loop"
if [[ "${TYPE}" == "FlatMuDaughter" ]]; then
  echo physics.producers.generate.pdgId: ${PDG}            >> primary.fcl
  echo physics.producers.generate.startMom: ${STARTMOM}    >> primary.fcl
  echo physics.producers.generate.endMom: ${ENDMOM}        >> primary.fcl
fi
#
# now generate the fcl
#
echo "generating"
generate_fcl --dsconf=${PRIMARY_CAMPAIGN} --dsowner=${OWNER} --run-number=${RUN} --description=${PRIMARY} --events-per-job=${EVENTS} --njobs=${JOBS} \
  --embed primary.fcl --auxinput=1:physics.filters.${resampler}.fileNames:Stops.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf ${PRIMARY}\_$dirname
  mv $dirname ${PRIMARY}\_$dirname
  echo "moving $dirname to ${PRIMARY}_${dirname}"
 fi
done

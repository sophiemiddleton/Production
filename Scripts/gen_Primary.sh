#!/usr/bin/bash
#
# create fcl for producing primaries from stopped particles
# this script requires mu2etools and dhtools be setup
#
# Usage: ./Production/Scripts/generate_Primary.sh --primary CeEndpoint --campaign MDC2020 --pver v --sver p --type Muminus --njobs 1000 --events 4000 --pdg 11 --start 0 --end 110 --field Offline/Mu2eG4/geom/bfgeom_reco_altDS11_helical_v01.txt
#
# Note: User can omit flat (pdg, startmom and enedmom) arguments without issue. Field argument also generally will not be used

# The main input parameters needed for any campaign
PRIMARY="" # is the primary
CAMPAIGN="" # Campaign (MDC2020"
PVER="" # production version
SVER="" # stops production version
TYPE="" # the kind of input stops (Muminus, Muplus, IPAMuminus, IPAMuplus, Piminus, Piplus)
JOBS="" # is the number of jobs
EVENTS="" # is the number of events/job

# The following can be overridden if needed
FLAT=""
PDG=11 #is the pdgId of the particle to generate (for flat only)
FIELD="Offline/Mu2eG4/geom/bfgeom_no_tsu_ps_v01.txt" #optional (for changing field map)
STARTMOM=0 # optional (for flat only)
ENDMOM=110 # optional (for flat only)
OWNER=mu2e
RUN=1202
CAT="Cat"

# Function: Print a help message.
usage() {
  echo "Usage: $0
  [ --primary primary physics name ]
  [ --campaign campaign name ]
  [ --pver primary campaign version ]]
  [ --sver stops campaign version ]
  [ --type stopped particle type ]
  [ --njobs number of jobs ]
  [ --events events per job ]
  [ --flat (opt) set to flat type ]
  [ --pdg (opt) for Flat spectra ]
  [ --start (opt) for Flat spectra ]
  [ --end (opt) for Flat spectra ]
  [ --field (opt) for special runs ]
  [ --owner (opt) default mu2e ]
  [ --run (opt) default 1202 ]
  [ --cat(opt) default Cat ]
  [ --setup (opt) expllicit simjob setup ]

  bash gen_Primary.sh --primary DIOTail --type Muminus --campaign MDC2020 --pver z_sm3 --sver p --njobs 100 --events 100 --start 75 --end 95 --setup /cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/MDC2020ag/setup.sh
  " 1>&2
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}


# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        primary)
          PRIMARY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        campaign)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        pver)
          PVER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        sver)
          SVER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        type)
          TYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        njobs)
          JOBS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        events)
          EVENTS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        flat)
          FLAT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        pdg)
          PDG=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        field)
          FIELD=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        start)
          STARTMOM=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        end)
          ENDMOM=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        run)
          RUN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        setup)
          SETUP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        cat)
          CAT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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

PRIMARY_CAMPAIGN=${CAMPAIGN}${PVER}
STOPS_CAMPAIGN=${CAMPAIGN}${SVER}

# basic tests
if [[ ${PRIMARY_CAMPAIGN} == ""  || ${PRIMARY} == "" || ${STOPS_CAMPAIGN} == "" || ${TYPE} == "" || ${JOBS} == "" || ${EVENTS} == "" ]]; then
  echo "Missing arguments ${PRIMARY_CAMPAIGN} ${PRIMARY} ${STOPS_CAMPAIGN} ${TYPE} ${JOBS} ${EVENTS} "
  exit_abnormal
fi

# Test: run a test to check the SimJob for this campaign verion exists TODO
DIR=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${PRIMARY_CAMPAIGN}
if [ -d "$DIR" ];
then
  echo "$DIR directory exists."
else
  echo "$DIR directory does not exist."
  exit 1
fi

dataset=sim.${OWNER}.${TYPE}Stops${CAT}.${STOPS_CAMPAIGN}.art

if [[ "${TYPE}" == "Muminus" ]] ||  [[ "${TYPE}" == "Muplus" ]]; then
  resampler=TargetStopResampler
elif [[ "${TYPE}" == "Piplus" ]]; then
  resampler=TargetPiStopResampler
elif [[ "${TYPE}" == "Piminus" ]]; then
  resampler=TargetPiStopResampler
  dataset=sim.${OWNER}.${TYPE}StopsFilt.${STOPS_CAMPAIGN}.art # since we prefilter these for a given time
else
  resampler=${TYPE}StopResampler
fi

if [[ "${TYPE}" == "Piminus" ]]; then
  samweb list-files "dh.dataset=$dataset and event_count > 0"  > Stops.txt
else
  samweb list-definition-files $dataset  > Stops.txt
fi
# calucate the max skip from the dataset

nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template
rm -f primary.fcl

FCLNAME="${PRIMARY%%_*}"
echo "#include \"Production/JobConfig/primary/${FCLNAME}.fcl\"" >> primary.fcl
echo physics.filters.${resampler}.mu2e.MaxEventsToSkip: ${nskip} >> primary.fcl
echo "services.GeometryService.bFieldFile : \"${FIELD}\"" >> primary.fcl
echo outputs.PrimaryOutput.fileName: \"dts.owner.${PRIMARY}.version.sequencer.art\"  >> primary.fcl
echo services.TFileService.fileName: \"nts.owner.GenPlots.version.sequencer.root\"  >> primary.fcl

if [[ "${PRIMARY}" == "DIOtail"* ]]; then
  echo physics.producers.generate.decayProducts.spectrum.ehi: ${ENDMOM}        >> primary.fcl
  echo physics.producers.generate.decayProducts.spectrum.elow: ${STARTMOM}    >> primary.fcl
  echo physics.filters.GenFilter.maxr_min : 320 >> primary.fcl
  echo physics.filters.GenFilter.maxr_max: 500 >> primary.fcl
fi

if [[ "${FLAT}" == "FlatMuDaughter" ]]; then
  echo physics.producers.generate.pdgId: ${PDG}            >> primary.fcl
  echo physics.producers.generate.startMom: ${STARTMOM}    >> primary.fcl
  echo physics.producers.generate.endMom: ${ENDMOM}        >> primary.fcl
fi

if [[ -n $SETUP ]]; then
  echo "Using user-provided setup $SETUP"
else
  SETUP=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${PRIMARY_CAMPAIGN}/setup.sh
fi

if [[ "$PROD" = true ]]; then
    rm cnf.*.tar
fi

cmd="mu2ejobdef --embed primary.fcl --setup ${SETUP} --run-number=${RUN} --events-per-job=${EVENTS} --desc ${PRIMARY} --dsconf ${PRIMARY_CAMPAIGN} --auxinput=1:physics.filters.${resampler}.fileNames:Stops.txt"

echo "Running: $cmd"
$cmd

parfile=$(ls cnf.*.tar)
# Remove cnf.
index_dataset=${parfile:4}
# Remove .0.tar
index_dataset=${index_dataset::-6}
idx_format=$(printf "%07d" ${JOBS})

if [[ "$PROD" = true ]]; then
    source gen_IndexDef.sh
fi

#!/usr/bin/bash
#
# create fcl for producing primaries from stopped particles
# this script requires mu2etools and dhtools be setup
#
# Note: User can omit flat (pdg, startmom and enedmom) arguments without issue. Field argument also generally will not be used

# The main input parameters needed for any campaign
DESC="" # is the desc
DSCONF="" # dsconf (MDC2020ab)"
RESAMPLER_NAME="" # the kind of input stops (TargetStopResampler, TargetPiStopResampler)
RESAMPLER_DATA="" # input dataset to resample (sim.mu2e.stoppedSimpleAntiprotons.MDC2020ap.art, sim.mu2e.MuminusStopsCat.MDC2020p.art, ...)
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
SET_FNAMES=True

# Function: Print a help message.
usage() {
cat <<EOF
Usage: $0 [options]

  --desc             NAME   desc physics name (required)
  --dsconf           NAME   dsconf label, e.g. MDC2020ap (required)
  --resampler_name   NAME   Resampler module name (required)
  --resampler_data   DATA   SAM dataset for resampler (required)
  --njobs            N      Number of jobs (required)
  --events           N      Events per job (required)

Optional:
  --fcl             FILE   FCL file to #include
  --flat            STR    Flat spectrum option, i.e. FlatMuDaughter
  --pdg             PDG    PDGid of particles to process
  --start_mom       MOM    Start momentum
  --end_mom         MOM    End momentum
  --field           FILE   Overridden field map
  --owner           STR    Default = mu2e
  --run             INT    Default = 1202
  --simjob_setup           FILE   Setup script
  --set_fnames      TRUE   Append dts names to the file
  --help                   Print this message

Example 1:
  $0 --desc DIOtail --dsconf MDC2020ap --resampler_name TargetStopResampler \\
     --resampler_data sim.mu2e.stoppedSimpleAntiprotons.MDC2020ap.art --njobs 100 --events 100
Example 2:
  $0 --desc CosmicCRY --fcl Production/JobConfig/cosmic/S2Resampler.fcl --dsconf MDC2020ap \\
     --resampler_name CosmicResampler --njobs 20 --events 100000 --run 1210 --resampler_data sim.mu2e.CosmicDSStopsCRY.010622.art
Example 3:
  $0 --desc AntiprotonStop --dsconf MDC2020ap --resampler_name TargetStopResampler \\
     --njobs 20 --events 100000 --run 1210 --resampler_data sim.mu2e.stoppedSimpleAntiprotons.MDC2020ap.art

EOF
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
        desc)
          DESC=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        fcl)
          FCL=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dsconf)
          DSCONF=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        resampler_name)
          RESAMPLER_NAME=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        njobs)
          JOBS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        events)
          EVENTS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        resampler_data)
          RESAMPLER_DATA=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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
        start_mom)
          STARTMOM=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        end_mom)
          ENDMOM=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        run)
          RUN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        simjob_setup)
          SIMJOB_SETUP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        set_fnames)
          SET_FNAMES=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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


echo "RESAMPLER_NAME: ${RESAMPLER_NAME}"
# basic tests
if [[ ${DSCONF} == "" || ${DESC} == ""|| ${RESAMPLER_NAME} == "" || ${JOBS} == "" || ${EVENTS} == "" ]]; then
  echo "Missing arguments ${DSCONF} ${DESC} ${RESAMPLER_NAME} ${JOBS} ${EVENTS} "
  exit_abnormal
fi

# Test: run a test to check the SimJob for this dsconf verion exists TODO
DIR=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${DSCONF}
if [ -d "$DIR" ];
then
  echo "$DIR directory exists."
else
  echo "$DIR directory does not exist."
  exit 1
fi

echo "Input dataset: $RESAMPLER_DATA"
samweb list-files "dh.dataset=$RESAMPLER_DATA and event_count > 0"  > Stops.txt

# calucate the max skip from the RESAMPLER_DATA
nfiles=`samCountFiles.sh $RESAMPLER_DATA`
nevts=`samCountEvents.sh $RESAMPLER_DATA`
let nskip=nevts/nfiles

# write the template
rm -f primary.fcl
if [[ -n "$FCL" ]]; then
    echo "#include \"$FCL\"" > primary.fcl
else
    FCLNAME="${DESC%%_*}"
    echo "#include \"Production/JobConfig/primary/${FCLNAME}.fcl\"" > primary.fcl
fi
echo physics.filters.${RESAMPLER_NAME}.mu2e.MaxEventsToSkip: ${nskip} >> primary.fcl
echo "services.GeometryService.bFieldFile : \"${FIELD}\"" >> primary.fcl

#Append optional strings to the primary.fcl 
if [[ "${SET_FNAMES}" == "True" ]]; then
  echo outputs.PrimaryOutput.fileName: \"dts.owner.${DESC}.version.sequencer.art\"  >> primary.fcl
  echo services.TFileService.fileName: \"nts.owner.GenPlots.version.sequencer.root\"  >> primary.fcl
fi

if [[ "${DESC}" == "DIOtail"* ]]; then
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

if [[ -n $SIMJOB_SETUP ]]; then
  echo "Using user-provided setup $SIMJOB_SETUP"
else
  SIMJOB_SETUP=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${DSCONF}/setup.sh
fi

cat primary.fcl

[ "$PROD" = true ] && rm cnf.*.tar

# Mu2e jobdef command
cmd=(
  mu2ejobdef
  --embed primary.fcl
  --setup "${SIMJOB_SETUP}"
  --run-number="${RUN}"
  --events-per-job="${EVENTS}"
  --desc "${DESC}"
  --dsconf "${DSCONF}"
  --auxinput="1:physics.filters.${RESAMPLER_NAME}.fileNames:Stops.txt"
)
echo "Running: ${cmd[*]}"
"${cmd[@]}"


parfile=$(ls cnf.*.tar)
# Remove cnf.
index_dataset=${parfile:4}
# Remove .0.tar
index_dataset=${index_dataset::-6}
idx_format=$(printf "%07d" ${JOBS})

[ "$PROD" = true ] && source gen_IndexDef.sh

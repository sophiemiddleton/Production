#!/usr/bin/bash
# generate fcl for running mixing, a specialization of OnSpill digitization with pileup backgrounds
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database

# Function: Print a help message.
usage() {
  echo "Usage: $0   [ --primary primary physics process name ]   
  [ --campaign campaign name e.g. MDC2020 ]   
  [ --mver mixin (input) campaign version e.g. 'p' ]   
  [ --over output campaign version e.g. 'v' ]   
  [ --pbeam proton beam intensity e.g. Mix1BB (one Booster Batch), Mix2BB, MixLow, or MixSeq (sequential)]   
  [ --dbpurpose purpose of db e.g. perfect, startup, best  ]   
  [ --dbversion db version ]   
  [ --early (opt) for early digitization.  Intensity will be set to 'Low' ]   
  [ --merge-events (opt) merge events, default 5000 ]   
  [ --owner (opt) default mu2e ]   
  [ --field (opt) default = DS +TSD, override for special runs ]   
  [ --neutmix (opt) # of neutral pileup files ]   
  [ --elemix (opt) # of electron pileup files ]   
  [ --mustopmix (opt) # of mustop daughter pileup files ]   [ --mubeammix (opt) # of mubeam pileup files ]   
  [ --primary_dataset dts.mu2e.desc.dsconf.art ]"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# required configuration parameters
CAMPAIGN="MDC2020"
OUTPUT_VERSION=""
MIXIN_VERSION=""
DBPURPOSE=""
DBVERSION="v1_3"
PBEAM=""
EARLY=""
MERGE_EVENTS=5000 #source events in mixing
OWNER=mu2e
NEUTNMIXIN=50
ELENMIXIN=25
MUSTOPNMIXIN=2
MUBEAMNMIXIN=1
FIELD="Offline/Mu2eG4/geom/bfgeom_no_tsu_ps_v01.txt"
PRIMARY_DATASET=""
PUSHOUT=false

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        campaign)
          CAMPAIGN=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        mver)
          MIXIN_VERSION=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        over)
          OUTPUT_VERSION=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        pbeam)
          PBEAM=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbpurpose)
          DBPURPOSE=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbversion)
          DBVERSION=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        early)
          EARLY=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        merge-events)
          MERGE_EVENTS=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        neutmix)
          NEUTNMIXIN=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        elemix)
          ELENMIXIN=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        mustopmix)
          MUSTOPNMIXIN=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        mubeammix)
          MUBEAMNMIXIN=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        field)
          FIELD=${!OPTIND}
          OPTIND=$(( $OPTIND + 1 ))
          ;;
        primary_dataset)
            PRIMARY_DATASET=${!OPTIND}
            OPTIND=$(( $OPTIND + 1 ))
            ;;
	pushout)
	    PUSHOUT=${!OPTIND}
	    OPTIND=$(( $OPTIND + 1 ))
	    ;;

      esac
      ;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)
      echo "Unknown option ${OPTARG}"
      exit_abnormal
      ;;
  esac
done


# basic tests
if [[ ${PRIMARY_DATASET} == "" || ${MIXIN_VERSION} == "" || ${OUTPUT_VERSION} == "" || ${PBEAM} == "" || ${DBPURPOSE} == "" ]]; then
  echo "Missing arguments: exit"
  exit_abnormal
fi

IFS='.' read -r _ _ PRIMARY_DESC _ _ <<< "$PRIMARY_DATASET"

if [[ ${EARLY} == "Early" ]]; then
  echo "Early mixing selected"
  NEUTNMIXIN=1
  ELENMIXIN=1
  MUSTOPNMIXIN=1
  MUBEAMNMIXIN=1
  PBEAM="Low"
fi

# define configuration fields for primary, mixin, and output
MIXINCONF=${CAMPAIGN}${MIXIN_VERSION}
DSCONF=${CAMPAIGN}${OUTPUT_VERSION}_${DBPURPOSE}_${DBVERSION}

# output collection description root
DESC=${PRIMARY_DESC}${PBEAM}${EARLY}

# consistency check: cannot mix Extracted or NoField data
if [[ "${PRIMARY_DESC}" == *"Extracted" || "${PRIMARY_DESC}" == *"NoField" ]]; then
  echo "Primary ${PRIMARY_DESC} incompatible with mixing; aborting"
  exit_abnormal
fi

# Test: check the SimJob for this campaign version exists
DIR=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${CAMPAIGN}${OUTPUT_VERSION}
if [ -d "$DIR" ];
then
  echo "Musing $DIR exists."
else
  echo "Musing $DIR does not exist."
  exit_abnormal
fi

echo "Generating mixing scripts for ${PRIMARY_DESC} mixin version ${MIXIN_VERSION} output version, description ${OUTPUT_VERSION} ${DESC}"

# create the mixin input lists.  Note there is no early MuStopPileup.
MUBEAMPILEUP=${EARLY}MuBeamFlashCat${MIXINCONF}.txt
EBEAMPILEUP=${EARLY}EleBeamFlashCat${MIXINCONF}.txt
NPILEUP=${EARLY}NeutralsFlashCat${MIXINCONF}.txt
MUSTOPPILEUP=MuStopPileupCat${MIXINCONF}.txt

#Cleanup older files
rm -f $MUBEAMPILEUP $EBEAMPILEUP $NPILEUP $MUSTOPPILEUP

samweb list-definition-files "dts.mu2e.${EARLY}MuBeamFlashCat.${MIXINCONF}.art" > ${MUBEAMPILEUP}
samweb list-definition-files "dts.mu2e.${EARLY}EleBeamFlashCat.${MIXINCONF}.art" > ${EBEAMPILEUP}
samweb list-definition-files "dts.mu2e.${EARLY}NeutralsFlashCat.${MIXINCONF}.art" > ${NPILEUP}
samweb list-definition-files "dts.mu2e.MuStopPileupCat.${MIXINCONF}.art" > ${MUSTOPPILEUP}

# calculate the max skip from the dataset
nfiles=$(samCountFiles.sh "dts.mu2e.MuBeamFlashCat.${MIXINCONF}.art")
nevts=$(samCountEvents.sh "dts.mu2e.MuBeamFlashCat.${MIXINCONF}.art")
let nskip_MuBeamFlash=nevts/nfiles
nfiles=$(samCountFiles.sh "dts.mu2e.EleBeamFlashCat.${MIXINCONF}.art")
nevts=$(samCountEvents.sh "dts.mu2e.EleBeamFlashCat.${MIXINCONF}.art")
let nskip_EleBeamFlash=nevts/nfiles
nfiles=$(samCountFiles.sh "dts.mu2e.NeutralsFlashCat.${MIXINCONF}.art")
nevts=$(samCountEvents.sh "dts.mu2e.NeutralsFlashCat.${MIXINCONF}.art")
let nskip_NeutralsFlash=nevts/nfiles
nfiles=$(samCountFiles.sh "dts.mu2e.MuStopPileupCat.${MIXINCONF}.art")
nevts=$(samCountEvents.sh "dts.mu2e.MuStopPileupCat.${MIXINCONF}.art")
let nskip_MuStopPileup=nevts/nfiles

# write the mix.fcl
rm -f mix.fcl
echo '#include "Production/JobConfig/mixing/Mix.fcl"' >> mix.fcl

if [[ -n $SETUP ]]; then
  echo "Using user-provided setup $SETUP"
else
  SETUP=${DIR}/setup.sh
fi

# locate the primary collection
rm -f ${PRIMARY_DESC}.txt
samweb list-definition-files "${PRIMARY_DATASET}" > ${PRIMARY_DESC}.txt

nfiles=$(samCountFiles.sh ${PRIMARY_DATASET})
nevts=$(samCountEvents.sh ${PRIMARY_DATASET})
let npevents=nevts/nfiles
let MERGE_FACTOR=MERGE_EVENTS/npevents+1
echo $MERGE_FACTOR

# Setup the beam intensity model
case "$PBEAM" in
    Mix1BB) pbeam_fcl=OneBB.fcl ;;
    Mix2BB) pbeam_fcl=TwoBB.fcl ;;
    MixLow) pbeam_fcl=LowIntensity.fcl ;;
    MixSeq) pbeam_fcl=NoPrimaryPBISequence.fcl ;;
    *) echo "Unknown PBEAM $PBEAM"; exit_abnormal ;;
esac
echo "#include \"Production/JobConfig/mixing/${pbeam_fcl}\"" >> mix.fcl

# setup option for early digitization
if [ "${EARLY}" == "Early" ]; then
  echo '#include "Production/JobConfig/mixing/EarlyMixins.fcl"' >> mix.fcl
fi

# NoPrimary needs a special filter
if [ "${PRIMARY_DESC}" == "NoPrimary" ]; then
  echo '#include "Production/JobConfig/mixing/NoPrimary.fcl"' >> mix.fcl
fi

# Override dts filters conditioned on primary
filter="Production/JobConfig/mixing/filters/${PRIMARY_DESC}.fcl"
if test -f "${PRODUCTION_INC}/${filter}"; then
  echo "#include \"${filter}\"" >> mix.fcl
fi

# set the skips
echo physics.filters.MuBeamFlashMixer.mu2e.MaxEventsToSkip: ${nskip_MuBeamFlash} >> mix.fcl
echo physics.filters.EleBeamFlashMixer.mu2e.MaxEventsToSkip: ${nskip_EleBeamFlash} >> mix.fcl
echo physics.filters.NeutralsFlashMixer.mu2e.MaxEventsToSkip: ${nskip_NeutralsFlash} >> mix.fcl
echo physics.filters.MuStopPileupMixer.mu2e.MaxEventsToSkip: ${nskip_MuStopPileup} >> mix.fcl

# setup database access, for SimEfficiences and digi parameters
echo services.DbService.purpose: ${CAMPAIGN}_${DBPURPOSE} >> mix.fcl
echo services.DbService.version: ${DBVERSION} >> mix.fcl
echo services.DbService.verbose : 2 >> mix.fcl
echo "services.GeometryService.bFieldFile : \"${FIELD}\"" >> mix.fcl
# overwrite the outputs
echo outputs.TriggeredOutput.fileName: \"dig.owner.${DESC}Triggered.version.sequencer.art\" >> mix.fcl
echo outputs.TriggerableOutput.fileName: \"dig.owner.${DESC}Triggerable.version.sequencer.art\" >> mix.fcl

cmd=(
    mu2ejobdef --dsconf=${DSCONF} --dsowner=${OWNER} --description=${DESC} --embed mix.fcl --setup ${SETUP}
    --inputs=${PRIMARY_DESC}.txt --merge-factor=${MERGE_FACTOR}
    --auxinput=${MUSTOPNMIXIN}:physics.filters.MuStopPileupMixer.fileNames:${MUSTOPPILEUP}
    --auxinput=${ELENMIXIN}:physics.filters.EleBeamFlashMixer.fileNames:${EBEAMPILEUP}
    --auxinput=${MUBEAMNMIXIN}:physics.filters.MuBeamFlashMixer.fileNames:${MUBEAMPILEUP}
    --auxinput=${NEUTNMIXIN}:physics.filters.NeutralsFlashMixer.fileNames:${NPILEUP}
)

echo "Running: ${cmd[*]}"
${cmd[@]}

# Locate the parfile and extract an index dataset name using parameter expansion
parfile="cnf.${OWNER}.${DESC}.${DSCONF}.0.tar"
echo "parfile: $parfile"

test_fcl=${parfile}.fcl
mu2ejobfcl --jobdef $parfile --index 0 --default-proto root --default-loc tape > ${test_fcl}
cat ${test_fcl}


# Create outputs.txt to optionally push output
rm -f outputs.txt
echo "disk $parfile none" > outputs.txt

if [[ "$PUSHOUT" != true ]]; then
  echo "PushOutput disabled."
elif samweb locate-file "$parfile" >/dev/null 2>&1; then
  echo "File exists on SAM; not pushing output."
else
  pushOutput outputs.txt
fi

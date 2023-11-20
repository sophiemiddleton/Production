#!/usr/bin/bash
# generate fcl for running mixing, a specialization of OnSpill digitization with pileup backgrounds
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
# Function: Print a help message.
usage() { echo "Usage: $0
  [ --primary primary physics process name ]
  [ --campaign campaign name e.g. MDC2020 ]
  [ --pver primary campaign version e.g 'r']
  [ --mver mixin (input) campaign version e.g. 'p' ]
  [ --over output campaign version e.g. 'v' ]
  [ --pbeam proton beam intensity e.g. 1BB (one Booster Batch), 2BB, Low, or Seq (sequential)]
  [ --dbpurpose purpose of db e.g. perfect, startup, best  ]
  [ --dbversion db version ]
  [ --early (opt) for early digitization.  Intensity will be set to 'Low' ]
  [ --merge (opt) merge factor, default 10 ]
  [ --owner (opt) default mu2e ]
  [ --samopt (opt) Options to samListLocation default "-f --schema=root" ]
  [ --field (opt) default = DS +TSD, override for special runs ]
  [ --neutmix (opt) # of neutral pileup files ]
  [ --elemix (opt) # of electron pileup files ]
  [ --mustopmix (opt) # of mustop daughter pileup files ]
  [ --mubeammix (opt) # of mubeam pileup files ]
    e.g.  Production/Scripts/gen_Mix.sh --primary CeEndpoint --campaign MDC2020 --pver t --mver p --over v --pbeam 1BB --dbpurpose perfect --dbversion v1_0"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# required configuration parameters
PRIMARY=""
CAMPAIGN=""
PRIMARY_VERSION=""
OUTPUT_VERSION=""
MIXIN_VERSION=""
DBPURPOSE=""
DBVERSION=""
PBEAM=""
EARLY=""
MERGE=10
OWNER=mu2e
NEUTNMIXIN=50
ELENMIXIN=25
MUSTOPNMIXIN=2
MUBEAMNMIXIN=1
SAMOPT="-f --schema=root"
FIELD="Offline/Mu2eG4/geom/bfgeom_no_tsu_ps_v01.txt"


# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        campaign)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        primary)
          PRIMARY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        pver)
          PRIMARY_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        mver)
          MIXIN_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        over)
          OUTPUT_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        pbeam)
          PBEAM=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbpurpose)
          DBPURPOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dbversion)
          DBVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        early)
          EARLY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        merge)
          MERGE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        samopt)
          SAMOPT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        neutmix)
          SAMOPT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        field)
          FIELD=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        neutmix)
          NEUTNMIXIN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        elemix)
          ELENMIXIN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        mustopmix)
          MUSTOPNMIXIN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        mubeammix)
          MUBEAMNMIXIN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        esac;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Exit abnormally.
      ;;
    *)                                    # If unknown (any other) option:
      echo "Unknown option ${OPTARG}"
      exit_abnormal                       # Exit abnormally.
      ;;
    esac
done


# basic tests
#echo "${CAMPAIGN} ${PRIMARY} ${PRIMARY_VERSION} ${MIXIN_VERSION} ${OUTPUT_VERSION} ${PBEAM} ${DBVERSION} ${DBPURPOSE}"
if [[ ${CAMPAIGN} == ""  || ${PRIMARY} == "" || ${PRIMARY_VERSION} == "" || ${MIXIN_VERSION} == "" || ${OUTPUT_VERSION} == "" || ${PBEAM} == "" || ${DBVERSION} == "" || ${DBPURPOSE} == "" ]]; then
  echo "Missing arguments: exit"
  exit_abnormal
fi


if [[ ${EARLY} == "Early" ]]; then
  echo "Early mixing selected"
  NEUTNMIXIN=1
  ELENMIXIN=1
  MUSTOPNMIXIN=1
  MUBEAMNMIXIN=1
  PBEAM="Low"
fi

# define configuration fields for primary, mixin, and output

PRIMARYCONF=${CAMPAIGN}${PRIMARY_VERSION}
MIXINCONF=${CAMPAIGN}${MIXIN_VERSION}
OUTCONF=${CAMPAIGN}${OUTPUT_VERSION}_${DBPURPOSE}_${DBVERSION}
# output collection description root
OUTDESC=${PRIMARY}Mix${PBEAM}${EARLY}

# consistency check: cannot mix Extracted or NoField data
if [[ "${PRIMARY}" == *"Extracted" || "${PRIMARY}" == *"NoField" ]]; then
  echo "Primary ${PRIMARY} incompatible with mixing; aborting"
  exit_abnormal
fi

# Test: run a test to check the SimJob for this campaign verion exists
DIR=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${CAMPAIGN}${OUTPUT_VERSION}
if [ -d "$DIR" ];
  then
    echo "Musing $DIR exists."
  else
    echo "Musing $DIR does not exist."
    exit_abnormal
fi


echo "Generating mixing scripts for ${PRIMARY} primary version ${PRIMARY_VERSION} mixin version ${MIXIN_VERSION} output version, description ${OUTPUT_VERSION} ${OUTDESC}"

# create the mixin input lists.  Note there is no early MuStopPileup.  Reuse the files if they exist
MUBEAMPILEUP=${EARLY}MuBeamFlashCat${MIXINCONF}.txt
EBEAMPILEUP=${EARLY}EleBeamFlashCat${MIXINCONF}.txt
NPILEUP=${EARLY}NeutralsFlashCat${MIXINCONF}.txt
MUSTOPPILEUP=MuStopPileupCat${MIXINCONF}.txt
if [[ ! -f ${MUBEAMPILEUP} ]]; then
  samListLocations ${SAMOPT} --defname="dts.mu2e.${EARLY}MuBeamFlashCat.${MIXINCONF}.art"  > ${MUBEAMPILEUP}
fi
if [[ ! -f ${EBEAMPILEUP} ]]; then
  samListLocations ${SAMOPT} --defname="dts.mu2e.${EARLY}EleBeamFlashCat.${MIXINCONF}.art"  >${EBEAMPILEUP}
fi
if [[ ! -f ${NPILEUP} ]]; then
  samListLocations ${SAMOPT} --defname="dts.mu2e.${EARLY}NeutralsFlashCat.${MIXINCONF}.art" >${NPILEUP}
fi
if [[ ! -f ${MUSTOPPILEUP} ]]; then
  samListLocations ${SAMOPT} --defname="dts.mu2e.MuStopPileupCat.${MIXINCONF}.art" > ${MUSTOPPILEUP}
fi

# calucate the max skip from the dataset
nfiles=`samCountFiles.sh "dts.mu2e.MuBeamFlashCat.${MIXINCONF}.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuBeamFlashCat.${MIXINCONF}.art"`
let nskip_MuBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.EleBeamFlashCat.${MIXINCONF}.art"`
nevts=`samCountEvents.sh "dts.mu2e.EleBeamFlashCat.${MIXINCONF}.art"`
let nskip_EleBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.NeutralsFlashCat.${MIXINCONF}.art"`
nevts=`samCountEvents.sh "dts.mu2e.NeutralsFlashCat.${MIXINCONF}.art"`
let nskip_NeutralsFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.MuStopPileupCat.${MIXINCONF}.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuStopPileupCat.${MIXINCONF}.art"`
let nskip_MuStopPileup=nevts/nfiles
# write the mix.fcl
rm -f mix.fcl
# create a template file, starting from the basic Mix
echo '#include "Production/JobConfig/mixing/Mix.fcl"' >> mix.fcl
# locate the primary collection
samListLocations ${SAMOPT} --defname="dts.mu2e.${PRIMARY}.${PRIMARYCONF}.art" > ${PRIMARY}.txt

# Setup the beam intensity model
if [ ${PBEAM} == "1BB" ]; then
  echo '#include "Production/JobConfig/mixing/OneBB.fcl"' >> mix.fcl
elif [ ${PBEAM} == "2BB" ]; then
  echo '#include "Production/JobConfig/mixing/TwoBB.fcl"' >> mix.fcl
elif [ ${PBEAM} == "Low" ]; then
  echo '#include "Production/JobConfig/mixing/LowIntensity.fcl"' >> mix.fcl
elif [ ${PBEAM} == "Seq" ]; then
  echo '#include "Production/JobConfig/mixing/NoPrimaryPBISequence.fcl"' >> mix.fcl
else
  echo "Unknown proton beam intensity ${PBEAM}; aborting"
  exit_abnormal
fi
# setup option for early digitization
if [ "${EARLY}" == "Early" ]; then
  echo '#include "Production/JobConfig/mixing/EarlyMixins.fcl"' >> mix.fcl
fi
# NoPrimary needs a special filter
if [ "${PRIMARY}" == "NoPrimary" ]; then
  echo '#include "Production/JobConfig/mixing/NoPrimary.fcl"' >> mix.fcl
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
echo outputs.SignalOutput.fileName: \"dig.owner.${OUTDESC}Signal.version.sequencer.art\" >> mix.fcl
echo outputs.DiagOutput.fileName: \"dig.owner.${OUTDESC}Diag.version.sequencer.art\" >> mix.fcl
echo outputs.TrkOutput.fileName: \"dig.owner.${OUTDESC}Trk.version.sequencer.art\" >> mix.fcl
echo outputs.CaloOutput.fileName: \"dig.owner.${OUTDESC}Calo.version.sequencer.art\" >> mix.fcl
echo outputs.UntriggeredOutput.fileName: \"dig.owner.${OUTDESC}Untriggered.version.sequencer.art\" >> mix.fcl

# run generate_fcl
generate_fcl --dsconf="${OUTCONF}" --dsowner=${OWNER} --description="${OUTDESC}" --embed mix.fcl \
  --inputs="${PRIMARY}.txt" --merge-factor=${MERGE} \
  --auxinput=${MUSTOPNMIXIN}:physics.filters.MuStopPileupMixer.fileNames:${MUSTOPPILEUP}  \
  --auxinput=${ELENMIXIN}:physics.filters.EleBeamFlashMixer.fileNames:${EBEAMPILEUP} \
  --auxinput=${MUBEAMNMIXIN}:physics.filters.MuBeamFlashMixer.fileNames:${MUBEAMPILEUP} \
  --auxinput=${NEUTNMIXIN}:physics.filters.NeutralsFlashMixer.fileNames:${NPILEUP}
#  move to an appropriate directory
for dirname in 000 001 002 003 004 005 006 007 008 009; do
  if test -d $dirname; then
    echo "found dir $dirname"
    MDIR="${OUTDESC}Mix_${dirname}"
    if test -d $MDIR; then
      echo "removing $MDIR"
      rm -rf $MDIR
    fi
    echo "moving $dirname to $MDIR"
    mv $dirname $MDIR
  fi
done
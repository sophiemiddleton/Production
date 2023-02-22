#!/usr/bin/bash
usage() { echo "Usage:
  ..."
}

PRIMARY="" # e.g. CeEndpoint
MIXCAMP="" # e.g MDC2020p
PCAMP=""  # e.g. MDC2020v
DBPURPOSE="" # e.g. perfect
DBVERSION="" # e.g. v1_0
NBB="" # e.g.1BB
EARLY=""
MERGE=10
OWNER=mu2e
NEUTNMIXIN=50
ELENMIXIN=25
MUSTOPNMIXIN=2
MUBEAMNMIXIN=1


# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in 
    -)                                   
      case "${OPTARG}" in
        primary)
          PRIMARY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))      
          ;;
        mcamp)            
          MIXCAMP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))      
          ;;
        pcamp)            
          PCAMP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                
          ;;
        dbpurpose)
          DBPURPOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                   
          ;;
        dbversion)
          DBVERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                  
          ;;
        nbb)
          NBB=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                  
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
      exit_abnormal                       # Exit abnormally.
      ;;
    esac
done


if [[ ${EARLY} -eq "Early" ]]; then
  NEUTNMIXIN=1
  ELENMIXIN=1
  MUSTOPNMIXIN=1
  MUBEAMNMIXIN=1
  NBB="Low"
fi

OUTCONF=${PCAMP}_${DBPURPOSE}_${DBVERSION}
MIXOUT=${PRIMARY}Mix${NBB}${EARLY}

# consistency check: cannot mix Extracted or NoField data
if [[ "${PRIMARY}" == *"Extracted" || "${PRIMARY}" == *"NoField" ]]; then
  echo "Primary ${PRIMARY} incompatible with mixing; aborting"
  return 1
fi

echo "Generating mixing scripts for ${PRIMARY} conf ${PCAMP} mixin conf ${MIXCAMP} output conf ${OUTCONF} database purpose, version ${DBPURPOSE} ${DBVERSION} ${EARLY} with ${NBB} proton intensity"

 create the mixin input lists.  Note there is no early MuStopPileup
samweb list-file-locations --schema=root --defname="dts.mu2e.${EARLY}MuBeamFlashCat.${MIXCAMP}.art"  | cut -f1 > MuBeamFlashCat${MIXCAMP}.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.${EARLY}EleBeamFlashCat.${MIXCAMP}.art"  | cut -f1 > EleBeamFlashCat${MIXCAMP}.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.${EARLY}NeutralsFlashCat.${MIXCAMP}.art"  | cut -f1 > NeutralsFlashCat${MIXCAMP}.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.MuStopPileupCat.${MIXCAMP}.art"  | cut -f1 > MuStopPileupCat${MIXCAMP}.txt

# calucate the max skip from the dataset
nfiles=`samCountFiles.sh "dts.mu2e.MuBeamFlashCat.${MIXCAMP}.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuBeamFlashCat.${MIXCAMP}.art"`
let nskip_MuBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.EleBeamFlashCat.${MIXCAMP}.art"`
nevts=`samCountEvents.sh "dts.mu2e.EleBeamFlashCat.${MIXCAMP}.art"`
let nskip_EleBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.NeutralsFlashCat.${MIXCAMP}.art"`
nevts=`samCountEvents.sh "dts.mu2e.NeutralsFlashCat.${MIXCAMP}.art"`
let nskip_NeutralsFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.MuStopPileupCat.${MIXCAMP}.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuStopPileupCat.${MIXCAMP}.art"`
let nskip_MuStopPileup=nevts/nfiles
# write the mix.fcl
rm -f mix.fcl
# create a template file, starting from the basic Mix
echo '#include "Production/JobConfig/mixing/Mix.fcl"' >> mix.fcl
# locate the primary collection
samweb list-file-locations --schema=root --defname="dts.mu2e.${PRIMARY}.${PCAMP}.art"  | cut -f1 > ${PRIMARY}.txt

# Setup the beam intensity model
if [ ${NBB} == "1BB" ]; then
  echo '#include "Production/JobConfig/mixing/OneBB.fcl"' >> mix.fcl
elif [ ${NBB} == "2BB" ]; then
  echo '#include "Production/JobConfig/mixing/TwoBB.fcl"' >> mix.fcl
elif [ ${NBB} == "Low" ]; then
  echo '#include "Production/JobConfig/mixing/LowIntensity.fcl"' >> mix.fcl
elif [ ${NBB} == "Seq" ]; then
  echo '#include "Production/JobConfig/mixing/NoPrimaryPBISequence.fcl"' >> mix.fcl
else
  echo "Unknown proton beam intensity ${NBB}; aborting"
  return 1;
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
echo services.DbService.purpose: ${DBPURPOSE} >> mix.fcl
echo services.DbService.version: ${DBVERSION} >> mix.fcl
echo services.DbService.verbose : 2 >> mix.fcl
# overwrite the outputs
echo outputs.SignalOutput.fileName: \"dig.owner.${MIXOUT}Signal.version.sequencer.art\" >> mix.fcl
echo outputs.DiagOutput.fileName: \"dig.owner.${MIXOUT}Diag.version.sequencer.art\" >> mix.fcl
echo outputs.TrkOutput.fileName: \"dig.owner.${MIXOUT}Trk.version.sequencer.art\" >> mix.fcl
echo outputs.CaloOutput.fileName: \"dig.owner.${MIXOUT}Calo.version.sequencer.art\" >> mix.fcl
echo outputs.UntriggeredOutput.fileName: \"dig.owner.${MIXOUT}Untriggered.version.sequencer.art\" >> mix.fcl

# run generate_fcl
generate_fcl --dsconf="${OUTCONF}" --dsowner=${OWNER} --description="${MIXOUT}" --embed mix.fcl \
  --inputs="${PRIMARY}.txt" --merge-factor=${MERGE} \
  --auxinput=${MUSTOPNMIXIN}:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat${MIXCAMP}.txt \
  --auxinput=${ELENMIXIN}:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat${MIXCAMP}.txt \
  --auxinput=${MUBEAMNMIXIN}:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat${MIXCAMP}.txt \
  --auxinput=${NEUTNMIXIN}:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat${MIXCAMP}.txt
#  move to an appropriate directory
for dirname in 000 001 002 003 004 005 006 007 008 009; do
  if test -d $dirname; then
    echo "found dir $dirname"
    if test -d ${MIXOUT}_${dirname}; then
      echo "removing ${MIXOUT}_${dirname}"
      rm -rf "${MIXOUT}_${dirname}"
    fi
    echo "moving $dirname to ${MIXOUT}_${dirname}"
    mv $dirname ${MIXOUT}\_$dirname
  fi
done

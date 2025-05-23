#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g. Stage3_mixsignal.sh --known MDS2a --signal CeMLeadingLog --rmue 1e-14
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
OWNER="mu2e"
KNOWN="MDS2a" #background sample
VERBOSE=1
RMUE=1e-13
SIGNAL="CeMLeadingLog" #name as given to primary during production
DBPURPOSE="perfect"
DBVERSION="v1_3"

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        known)
          KNOWN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rmue)
          RMUE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        signal)
          SIGNAL=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        *)
          echo "Unknown option " ${OPTARG}
          exit_abnormal
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

# step 1: check livetime of the tag
CONFIG=${KNOWN}.txt
while IFS='= ' read -r col1 col2
do 
    if [[ "${col1}" == "livetime" ]] ; then
      LIVETIME=${col2}
    fi
    if [[ "${col1}" == "BB" ]] ; then
      BB=${col2}
    fi
    
done <${CONFIG}
echo "extracted config for ${KNOWN}"
echo ${LIVETIME} ${BB}

# step 2: calculate yield of signal for chose rate, if > 0 then proceed --> use python scripts
${NSIG}=calculateEvents.py --livetime ${LIVETIME} --prc ${SIGNAL} --BB ${BB} --rmue ${RMUE}
echo "${RMUE} for ${BB} and ${LIVETIME} s means ${NSIG} events will be sampled"

#step 3: figure out the efficiency and factor that in (nsig_reco = eff*nsig)

# step 4: find appropriate signal samples
samweb list-files "dh.dataset=mcs.mu2e.${SIGNAL}OnSpillTriggered.${RELEASE}_${DBPURPOSE}_${DBVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_signal.txt

# step 5: understand how many events are present, and what fraction we need to sample
samweb list-files mcs.mu2e.${SIGNAL}OnSpillTriggered.${RELEASE}_${DBPURPOSE}_${DBVERSION}.art | head -n 1 | xargs -I {} samweb get-metadata {} | grep dh.gencount | awk '{print $2}' > ${NGEN}

echo ${SAMPLING}



#step 6: configure fcl that will sample at this rate and mix the signal with background

#step 7: submit to the grid

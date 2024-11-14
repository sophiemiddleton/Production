#!/usr/bin/bash

# The main input parameters needed for any campaign
CAMPAIGN="" # Campaign MDC2020"
PVER="" # production version
SVER="" # stops production version
OWNER=mu2e
SETUP=""
# Function: Print a help message.
usage() {
  echo "Usage: $0
  [ --campaign campaign name ]
  [ --pver primary campaign version ]]
  [ --sver stops campaign version ]
  [ --owner (opt) default mu2e ]
  [ --setup (opt) expllicit simjob setup ]
  bash gen_PiFilter.sh --campaign MDC2020 --pver aj --sver t --owner mu2e 
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
        campaign)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        pver)
          PVER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        sver)
          SVER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        setup)
          SETUP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
      esac;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Exit abnormally.
      ;;
    *)               # If unknown (any other) option:
      exit_abnormal                       # Exit abnormally.
      ;;
  esac
done

PRIMARY_CAMPAIGN=${CAMPAIGN}${PVER}
STOPS_CAMPAIGN=${CAMPAIGN}${SVER}

# basic tests
if [[ ${PRIMARY_CAMPAIGN} == ""  || ${STOPS_CAMPAIGN} == "" ]]; then
  echo "Missing arguments ${PRIMARY_CAMPAIGN} ${STOPS_CAMPAIGN} "
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

dataset=sim.${OWNER}.PiminusStopsCat.${STOPS_CAMPAIGN}.art # since we prefilter these for a given time

samweb list-definition-files $dataset  > Stops.txt

# calucate the max skip from the dataset
nfiles=`samCountFiles.sh $dataset`
nevts=`samCountEvents.sh $dataset`
let nskip=nevts/nfiles
# write the template
rm -f pifilter.fcl

echo "#include \"Production/JobConfig/primary/TargetPiStopPreFilter.fcl\"" >> pifilter.fcl
echo outputs.StopFilterOutput.fileName: \"sim.${OWNER}.PiminusStopsFilt.version.sequencer.art\"  >> pifilter.fcl


if [[ -n $SETUP ]]; then
  echo "Using user-provided setup $SETUP"
else
  SETUP=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${PRIMARY_CAMPAIGN}/setup.sh
fi

if [[ "$PROD" = true ]]; then
    rm cnf.*.tar
fi

cmd="mu2ejobdef --embed pifilter.fcl --setup ${SETUP} --desc PiminusStopsFilt --dsconf ${PRIMARY_CAMPAIGN} --inputs=Stops.txt --merge-factor=1"

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


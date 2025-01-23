#!/usr/bin/bash
#
# Script to run Stage2 (S2, resampling) DESC generation.  The output is Dts files ready for digitization

DESC=$1
CAMPAIGN=""
OWNER="mu2e"
S1_VERSION=""
OUTPUT_VERSION=""
NJOBS=0
NEVTS=0
RUNNUM=1202
S1TYPE=""
S1STOPS=""
SETUP=""

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# Function: Print a help message.
usage() {
   echo "Usage: $0
  [ --desc Cosmic S1 gen type (CRY, CORSIKA, ...)  ]
  [ --campaign name of the campaign]
  [ --s1ver campaign version of S1 input]
  [ --over campaign version of S2 output]
  [ --njobs  N jobs ]
  [ --nevents  N events/job ]
  [ --owner (opt) default mu2e ]
  [ --s1stops (opt) expllicit list stop definition ]
  [ --setup (opt) expllicit simjob setup ]
  [ --fcl (opt) optionally fcl to the fcl template ]
  e.g. gen_S2Resample.sh --desc CORSIKA --campaign MDC2020 --s1ver ab --over ag --njobs 100 --nevents 100000 --owner mu2e --setup /cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/MDC2020ag/setup.sh ]" 1>&2
}

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        campaign)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        desc)
          DESC=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        s1ver)
          S1_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        over)
          OUTPUT_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        nevents)
          NEVTS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        njobs)
          NJOBS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        s1type)
          S1TYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        s1stops)
          S1STOPS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        setup)
          SETUP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        fcl)
          FCL=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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
if [[ ${NJOBS} == 0  || ${NEVTS} == 0 ]]; then
  echo "Missing arguments"
  exit_abnormal
fi

# create the fcl
rm -f ResampleS1.fcl
# create a template file, starting from the basic
cat $FCL  >> ResampleS1.fcl

OUTCONF=${CAMPAIGN}${OUTPUT_VERSION}
S1CONF=${CAMPAIGN}${S1_VERSION}

if [[ -n $S1STOPS ]]; then
  S1STOPS_FILE="S1stops.txt"
  samweb list-definition-files ${S1STOPS}  > ${S1STOPS_FILE}
else
  exit_abnormal
fi

if [[ -n $SETUP ]]; then
  echo "Using user-provided setup $SETUP"
else
  SETUP=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${S1CONF}/setup.sh
fi

cmd="mu2ejobdef --embed ResampleS1.fcl --setup ${SETUP} --run-number=${RUNNUM} --events-per-job=${NEVTS} --desc ${DESC} --dsconf ${OUTCONF} --auxinput=1:physics.filters.CosmicResampler.fileNames:${S1STOPS_FILE}"

echo "Running: $cmd"
$cmd

parfile=$(ls cnf.*.tar)
# Remove cnf.
index_dataset=${parfile:4}
# Remove .0.tar
index_dataset=${index_dataset::-6}

idx_format=$(printf "%07d" ${NJOBS})
echo $idx
echo "Creating index definiton with size: $idx"
samweb create-definition idx_${index_dataset} "dh.dataset etc.mu2e.index.000.txt and dh.sequencer < ${idx_format}"
echo "Created definiton: idx_${index_dataset}"
samweb describe-definition idx_${index_dataset}

# Clean up
#rm ResampleS1.fcl ${S1STOPS}

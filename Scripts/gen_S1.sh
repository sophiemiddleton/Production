#!/bin/bash

# Generate S1 job definitions for Mu2e

# Usage example:
#   bash Scripts/gen_S1.sh --dsconf MDC2020ap --owner mu2e --run 1202 --events 2000 --jobs 1000 --desc POT --fcl input.fcl --simjob_setup /path/to/setup.sh

# Default parameters (can be overridden via command-line arguments)
DSCONF=""
OWNER="mu2e"
RUN=1202
EVENTS=2000
NJOBS=1000
DESC="POT"
FCL="template.fcl"
SIMJOB_SETUP=""

# Function: Print a help message.
usage() {
  cat <<EOF
Usage: $0 [options]

  --dsconf         NAME   DSCONF label (required)
  --owner          NAME   Data owner (default: mu2e)
  --run            INT    Run number (default: 1202)
  --events         INT    Events per job (default: 2000)
  --njobs          INT    Number of jobs (default: 1000)
  --desc           NAME   Explicit DS stop files list (default: POT)
  --fcl            FILE   Input FCL file (default: template.fcl)
  --simjob_setup          FILE   Explicit SimJob setup file (required)
  --help                  Print this message

Example:
  $0 --dsconf MDC2020ap --owner mu2e --run 1202 --events 2000 --njobs 1000 \\
     --desc POT --fcl Production/JobConfig/beam/POT.fcl \\
     --simjob_setup /cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/MDC2020ap/setup.sh
EOF
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# Parse command-line options
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        dsconf)
          DSCONF=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        run)
          RUN=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        events)
          EVENTS=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        njobs)
          NJOBS=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        desc)
          DESC=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        fcl)
          FCL=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        simjob_setup)
          SIMJOB_SETUP=${!OPTIND} OPTIND=$((OPTIND + 1))
          ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "Invalid option: --${OPTARG}"
          exit_abnormal
          ;;
      esac;;
    :)  
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)  
      exit_abnormal
      ;;
  esac
done

# Validate required arguments
if [[ -z "$DSCONF" || -z "$SIMJOB_SETUP" ]]; then
  echo "Error: Missing required arguments."
  exit_abnormal
fi

[ "$PROD" = true ] && rm -f cnf.*.tar

# Print execution details
echo "Running mu2ejobdef command with the following options:"
echo "  DSCONF: $DSCONF"
echo "  Owner: $OWNER"
echo "  Run number: $RUN"
echo "  Events per job: $EVENTS"
echo "  NJobs: $NJOBS"
echo "  Description: $DESC"
echo "  FCL file: $FCL"
echo "  Simjob_Setup file: $SIMJOB_SETUP"
echo "  Production Mode: $PROD"

# Construct the mu2ejobdef command
cmd=(
  mu2ejobdef
  --verbose
  --setup "${SIMJOB_SETUP}"
  --dsconf "${DSCONF}"
  --dsowner "${OWNER}"
  --run-number "${RUN}"
  --events-per-job "${EVENTS}"
  --embed "${FCL}"
  --description "${DESC}"
)

echo "Running: ${cmd[*]}"
"${cmd[@]}"

# Process output files
parfile=$(ls cnf.*.tar)
index_dataset=${parfile:4}  # Remove "cnf."
index_dataset=${index_dataset::-6}  # Remove ".0.tar"
idx_format=$(printf "%07d" ${NJOBS})

# Run gen_IndexDef.sh in production mode
[ "$PROD" = true ] && source gen_IndexDef.sh

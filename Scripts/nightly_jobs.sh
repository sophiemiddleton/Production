#!/usr/bin/bash
#
# Script for creating nightly validation jobs
# option to just create the fcl, or to submit them
# Original author: Dave Brown (LBNL) April 2025
#

usage() { echo "Usage: $0
  --dir : Directory under Production/Validation/nightly to find the script
  --script: Script name in the above directory to process
  [ --type "jobtype"]: either primary, resample, or read (default)
  [ --dataset : Dataset to process (if needed) ]
  [ --resample : Resampler stream ]
  [ --location "location" ] : location to fine dataset (default tape)
  [ --submit / --nosubmit] : submit the jobs or just create the fcl (default nosubmit)
  [ --jobs N ] : Number of jobs to run (default 10)
  [ --merge N ] : Merge N inputs to 1 output (default 1)
  [ --run N --events M ] : Specify run # and events/job when no input dataset
  [ --help ] : Print this message.
  Note: Muse must be setup to point to the nightly build for this script to run"
}
exit_abnormal() {
  usage
  exit 1
}
VDIR=""
NIGHTLYBUILD="/pnfs/mu2e/resilient/users/mu2epro/nightly2"
NJOBS=10
MERGE=1
SUBMIT=""
SCRIPT=""
TYPE="read"
DATASET=""
RESAMPLE=""
DATE=`date --iso-8601`
LOC="tape"
RUN=1202
EVENTS=1000
NIGHTLY="/exp/mu2e/app/users/mu2epro/nightly2/current"
NUMBERS='^[0-9]+$'
declare -a LOCATIONS=("tape" "disk")
declare -a TYPES=("primary" "resample" "read")

while getopts ":-:h" LONGOPT; do
  case "${LONGOPT}" in
    -)
      case "${OPTARG}" in
        dir)
          VDIR=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        script)
          SCRIPT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        type)
          TYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dataset)
          DATASET=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          # add a test that the dataset exists TODO
          ;;
        resample)
          RESAMPLE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        location)
          LOC=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        submit)
          SUBMIT="yes"
          ;;
        nosubmit)
          SUBMIT=""
          ;;
        events)
          EVENTS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        run)
          RUN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        jobs)
          NJOBS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          if ! [[ $NJOBS =~ $NUMBERS ]] ; then
            echo "Invalid jobs value ${NJOBS}"
            exit_abnormal
          else
            echo "Preparing ${NJOBS} jobs"
          fi
          ;;
        merge)
          MERGE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          if ! [[ $MERGE =~ $NUMBERS ]] ; then
            echo "Invalid merge value ${MERGE}"
            exit_abnormal
          else
            echo "Merging ${MERGE} inputs to 1 output"
          fi
          ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "Unknown option ${OPTARG}"
          exit_abnormal
          ;;
      esac;;
    h)
      usage
      exit 0
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
FULLSCRIPT=Production/Validation/nightly/${VDIR}/${SCRIPT}.fcl
if [[ ! -f ${FULLSCRIPT} ]]; then
  echo "Validation script ${FULLSCRIPT} does not exist!"
  exit_abnormal
fi
goodtype="no"
for type in ${TYPES[@]}; do
  if [[ ${type} == ${TYPE} ]]; then
    goodtype="yes"
    echo "Preparing jobs of type ${TYPE}"
  fi
done
if [[ ${goodtype} == "no" ]]; then
  echo "Bad job type ${TYPE}; should be one of"
  for type in ${TYPES[@]}; do
    echo ${type}
  done
  exit_abnormal
fi
goodloc="no"
for loc in ${LOCATIONS[@]}; do
  if [[ ${loc} == ${LOC} ]]; then
    goodloc="yes"
  fi
done
if [[ ${goodloc} == "no" ]]; then
  echo "Bad dataset location ${LOC}; should be one of"
  for loc in ${LOCATIONS[@]}; do
    echo ${loc}
  done
  exit_abnormal
fi

# test setup and expand as needed
if [ -z ${OFFLINE_INC+x} ]; then
  echo "Setting up to use nightly build"
  source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
  muse setup /exp/mu2e/app/users/mu2epro/nightly2/current
  muse status
fi
if [[ ${OFFLINE_INC} != ${NIGHTLY} ]]; then
  echo "Incorrect Muse setup ${OFFLINE_INC}, expected ${NIGHTLY}"
  exit_abnormal
fi
# tools needed
setup mu2efiletools
setup mu2egrid
OUTDIR="/pnfs/mu2e/scratch/users/${USER}/${VDIR}Validation"
if [[ ! -d ${OUTDIR} ]]; then
  mkdir ${OUTDIR}
fi
if [[ ${DATASET} == "" ]]; then
# empty input, job must set run number and # of events
  RUN=1202
  EVENTS=1000
else
  INPUTS=${OUTDIR}/dts.${VDIR}${SCRIPT}.txt
  if [[ -f ${INPUTS} ]]; then
    rm -f ${INPUTS}
  fi
 mu2eDatasetFileList --basename ${DATASET} > ${INPUTS}
fi

JOBDEF="${OUTDIR}/cnf.${USER}.${VDIR}.${SCRIPT}.0.tar"
if [[ -f ${JOBDEF} ]]; then
  rm -f ${JOBDEF}
fi
# create the job definition
if [[ ${TYPE} == "primary" ]]; then
    mu2ejobdef --code ${NIGHTLYBUILD}/${DATE}.tgz --description ${VDIR} --dsconf ${SCRIPT} --dsowner ${USER} --run-number=${RUN} --events-per-job=${EVENTS} --embed ${FULLSCRIPT} --outdir ${OUTDIR}
else
  if [[ ${TYPE} == "resample" ]]; then
    AUXINPUT=${MERGE}:physics.filters.${RESAMPLE}.fileNames:${INPUTS}
    echo "Resampling ${AUXINPUT}"
    mu2ejobdef --code ${NIGHTLYBUILD}/${DATE}.tgz --description ${VDIR} --dsconf ${SCRIPT} --dsowner ${USER} --auxinput ${AUXINPUT} --run-number=${RUN} --events-per-job=${EVENTS} --embed ${FULLSCRIPT} --outdir ${OUTDIR}
  else
    mu2ejobdef --code ${NIGHTLYBUILD}/${DATE}.tgz --description ${VDIR} --dsconf ${SCRIPT} --dsowner ${USER} --inputs ${INPUTS} --merge-factor ${MERGE} --embed ${FULLSCRIPT} --outdir ${OUTDIR}
  fi
fi
if [[ ${SUBMIT} == "yes" ]];  then
  echo "Submitting ${NJOBS} jobs to the grid using ${JOBDEF}"
  mu2ejobsub --jobdef ${JOBDEF} --default-protocol ifdh --default-location ${LOC} --firstjob 0 --njobs ${NJOBS} --role production --memory 2GB
else
  echo "Creating ${NJOBS} job fcl using ${JOBDEF}"
  for IJOB in $(seq 0 $((${NJOBS}-1))) ; do
    JOBFILE=${OUTDIR}/${SCRIPT}_${IJOB}.fcl
    if [[ -f  ${JOBFILE} ]]; then
      rm -f ${JOBFILE}
    fi
    mu2ejobfcl --jobdef ${JOBDEF} --default-protocol file --default-location ${LOC} --index ${IJOB} > ${JOBFILE}
  done
fi

#!/usr/bin/bash
#
# Script for creating nightly validation jobs
# option to just create the fcl, or to submit them
# Original author: Dave Brown (LBNL) April 2025
#

usage() { echo "Usage: $0
  --dir : Directory under Production/Validation/nightly to find the script
  --script: Script name in the above directory to process
  --dataset : Dataset to process
  [ --submit / --nosubmit] : submit the jobs or just create the fcl (default nosubmit)
  [ --jobs N ] : Number of jobs to run (default 10)
  [ --merge N ] : Merge N inputs to 1 output (default 1)
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
NUMBERS='^[0-9]+$'
SCRIPT=""
DATASET=""
DATE=`date --iso-8601`
NIGHTLY="/exp/mu2e/app/users/mu2epro/nightly2/current"

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
        dataset)
          DATASET=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          # add a test that the dataset exists TODO
          ;;
        submit)
          SUBMIT="yes"
          ;;
        nosubmit)
          SUBMIT=""
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

if [[ ${DATASET} == "" ]]; then
  echo "Dataset unset"
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

INPUTS=${OUTDIR}/dts.${VDIR}${SCRIPT}.txt
if [[ -f ${INPUTS} ]]; then
  rm -f ${INPUTS}
fi

mu2eDatasetFileList --basename ${DATASET} > ${INPUTS}
JOBDEF="${OUTDIR}/cnf.${USER}.${VDIR}.${SCRIPT}.0.tar"
if [[ -f ${JOBDEF} ]]; then
  rm -f ${JOBDEF}
fi
# create the job definition
mu2ejobdef --code ${NIGHTLYBUILD}/${DATE}.tgz --description ${VDIR} --dsconf ${SCRIPT} --dsowner ${USER} --inputs ${INPUTS} --merge-factor ${MERGE} --embed ${FULLSCRIPT} --outdir ${OUTDIR}
if [[ ${SUBMIT} == "yes" ]];  then
  echo "Submitting ${NJOBS} jobs to the grid using ${JOBDEF}"
  mu2ejobsub --jobdef ${JOBDEF} --default-protocol ifdh --default-location tape --firstjob 0 --njobs ${NJOBS} --role production --memory 2GB
else
  echo "Creating ${NJOBS} job fcl using ${JOBDEF}"
  for IJOB in $(seq 0 $((${NJOBS}-1))) ; do
    JOBFILE=${OUTDIR}/${SCRIPT}_${IJOB}.fcl
    if [[ -f  ${JOBFILE} ]]; then
      rm -f ${JOBFILE}
    fi
    mu2ejobfcl --jobdef ${JOBDEF} --default-protocol file --default-location tape --index ${IJOB} > ${JOBFILE}
  done
fi

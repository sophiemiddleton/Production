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
  [ --submit / --nosubmit] : submit the jobs or just create the fcl
  [ --merge N ] : Merge N inputs to 1 output
  [ --help ] : Print this message"
}

exit_abnormal() {
  usage
  exit 1
}
NIGHTLYDIR="/pnfs/mu2e/resilient/users/mu2epro/nightly2"
OUTDIR="/pnfs/mu2e/scratch/users/${USER}/MDSValidation"
NJOBS=10
MERGE=1
SUBMIT=""
NUMBERS='^[0-9]+$'
SCRIPT=""
DATASET="dts.mu2e.ensembleMDS1e.MDC2020ar.art"
DATE=`date --iso-8601`
while getopts ":-:h" LONGOPT; do
  case "${LONGOPT}" in
    -)
      case "${OPTARG}" in
        dir)
          VALDIR=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        script)
          VALDIR=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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
FULLSCRIPT=Production/Validation/nightly/${DIR}/${SCRIPT}
if [[ ! -f ${FULLSCRIPT} ]]; then
  echo "Validation script ${FULLSCRIPT} does not exist!"
  exit_abnormal()
fi

if [[ ! -d ${OUTDIR} ]]; then
  mkdir ${OUTDIR}
fi
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup mu2efiletools
setup mu2egrid
muse setup /exp/mu2e/app/users/mu2epro/nightly2/current
INPUTS=${OUTDIR}/dts.mu2e.MDS.txt
if [[ -f ${INPUTS} ]]; then
  rm -f ${INPUTS}
fi
mu2eDatasetFileList --basename ${DATASET} > ${INPUTS}
JOBDEF="${OUTDIR}/cnf.${USER}.digitize.MDS.0.tar"
if [[ -f ${JOBDEF} ]]; then
  rm -f ${JOBDEF}
fi

mu2ejobdef --code ${NIGHTLYDIR}/${DATE}.tgz --description digitize --dsconf MDS --dsowner ${USER} --inputs ${INPUTS} --merge-factor ${MERGE} --embed ${FULLSCRIPT} --outdir ${OUTDIR}
if [[ ${SUBMIT} == "yes" ]];  then
  echo "Submitting ${NJOBS} jobs to the grid using ${JOBDEF}"
  mu2ejobsub --jobdef ${JOBDEF} --default-protocol ifdh --default-location tape --firstjob 1 --njobs ${NJOBS} --role production --memory 2GB
else
  echo "Creating ${NJOBS} job fcl using ${JOBDEF}"
  for IJOB in $(seq 1 ${NJOBS}); do
    JOBFILE=${OUTDIR}/digitize_${IJOB}.fcl
    if [[ -f  ${JOBFILE} ]]; then
      rm -f ${JOBFILE}
    fi
    mu2ejobfcl --jobdef ${JOBDEF} --default-protocol file --default-location tape --index ${IJOB} > ${JOBFILE}
  done
fi

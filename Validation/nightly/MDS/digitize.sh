#!/usr/bin/bash
#
# Script for creating MDS nightly digitization jobs
# option to just create the fcl, or to submit them
# Original author: Dave Brown (LBNL) April 2025
#

usage() { echo "Usage: $0
  [ --submit / --nosubmit] : submit the jobs or just create the fcl
  [ --Merge N ] : Merge N inputs to 1 output
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
DATASET="dts.mu2e.ensembleMDS1e.MDC2020ar.art"
DATE=`date --iso-8601`
while getopts ":-:h" LONGOPT; do
  case "${LONGOPT}" in
    -)
      case "${OPTARG}" in
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
if [[ ! -d ${OUTDIR} ]]; then
  mkdir ${OUTDIR}
fi
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup mu2efiletools
setup mu2egrid
muse setup /exp/mu2e/app/users/mu2epro/nightly2/current
mu2eDatasetFileList --basename ${DATASET} > ${OUTDIR}/dts.mu2e.MDS.txt
JOBDEF="${OUTDIR}/cnf.${USER}.digitize.MDS.0.tar"
if [[ -f ${JOBDEF} ]]; then
  rm -f ${JOBDEF}
fi
mu2ejobdef --code ${NIGHTLYDIR}/${DATE}.tgz --description digitize --dsconf MDS --dsowner ${USER} --inputs ${OUTDIR}/dts.mu2e.MDS.txt --merge-factor 1 --embed Production/Validation/nightly/MDS/digitize.fcl --outdir ${OUTDIR}
if [[ ${SUBMIT} == "yes" ]];  then
  echo "Submitting ${NJOBS} Jobs to the grid"
  mu2ejobsub --jobdef ${JOBDEF} --default-protocol ifdh --default-location tape --firstjob 1 --njobs ${NJOBS} --role production --memory 2GB
else
  echo "Creating ${NJOBS} Job fcl with ${OUTDIR}/cnf.${USER}.digitize.MDS.0.tar"
  for IJOB in $(seq 1 ${NJOBS}); do
    JOBFILE=${OUTDIR}/digitize_${IJOB}.fcl
    if [[ -f  ${JOBFILE} ]]; then
      rm -f ${JOBFILE}
    fi
    mu2ejobfcl --jobdef ${JOBDEF} --default-protocol file --default-location tape --index ${IJOB} > ${JOBFILE}
  done
fi

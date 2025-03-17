#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g. Stage2_submitensemble.sh --tag MDS1a
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
OWNER="mu2e"
INRELEASE=MDC2020
INVERSION=ar
TAG=""
VERBOSE=1
SETUP=/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/MDC2020ar/setup.sh


# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        tag)
          TAG=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        verbose)
          VERBOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        setup)
          SETUP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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

NJOBS="" #to help calculate the number of events per job
LIVETIME="" #seconds
RUN=1201
DIO_EMIN=""
RPC_EMIN=""
RMC_EMIN=""
IPA_EMIN=""
TMIN=""
BB=""
RMUE=""
SAMPLINGSEED=1
COSMICTAG=""
GEN=""
CONFIG=${TAG}.txt
OUTRELEASE="MDC2020"
OUTVERSION="ar"


while IFS='= ' read -r col1 col2
do 
    if [[ "${col1}" == "njobs" ]] ; then
      NJOBS=${col2}
    fi
    if [[ "${col1}" == "DIO_emin" ]] ; then
      DIO_EMIN=${col2}
    fi
    if [[ "${col1}" == "RPC_emin" ]] ; then
      RPC_EMIN=${col2}
    fi
    if [[ "${col1}" == "RPC_tmin" ]] ; then
      TMIN=${col2}
    fi
    if [[ "${col1}" == "RMC_emin" ]] ; then
      RMC_EMIN=${col2}
    fi
    if [[ "${col1}" == "IPA_emin" ]] ; then
      IPA_EMIN=${col2}
    fi
    if [[ "${col1}" == "livetime" ]] ; then
      LIVETIME=${col2}
    fi
    if [[ "${col1}" == "BB" ]] ; then
      BB=${col2}
    fi
    if [[ "${col1}" == "CosmicGen" ]] ; then
      GEN=${col2}
    fi
    if [[ "${col1}" == "CosmicTag" ]] ; then
      COSMICTAG=${col2}
    fi
done <${CONFIG}
echo "extracted config from Stage 1"
echo ${LIVETIME} ${DIO_EMIN} ${BB} ${RMUE}

rm filenames_${GEN}Cosmic
rm filenames_DIO
rm filenames_RPCInternal
rm filenames_RPCExternal
rm filenames_RMCInternal
rm filenames_RMCExternal
rm filenames_IPAMichel
rm *.tar

echo "accessing files, making file lists"
mu2eDatasetFileList "dts.mu2e.Cosmic${GEN}SignalAll.${COSMICTAG}.art" | head -${NJOBS} > filenames_${GEN}Cosmic
mu2eDatasetFileList "dts.mu2e.DIOtail_${DIO_EMIN}.${INRELEASE}${INVERSION}.art"| head -${NJOBS} > filenames_DIO
mu2eDatasetFileList "dts.mu2e.RPCInternal.${INRELEASE}${INVERSION}.art" | head -${NJOBS} > filenames_RPCInternal
mu2eDatasetFileList "dts.mu2e.RPCExternal.${INRELEASE}${INVERSION}.art" | head -${NJOBS} > filenames_RPCExternal
mu2eDatasetFileList "dts.mu2e.RMCInternal.${INRELEASE}${INVERSION}.art" | head -${NJOBS} > filenames_RMCInternal
mu2eDatasetFileList "dts.mu2e.RMCExternal.${INRELEASE}${INVERSION}.art" | head -${NJOBS} > filenames_RMCExternal
mu2eDatasetFileList "dts.mu2e.IPAMichel.${INRELEASE}${INVERSION}.art" | head -${NJOBS} > filenames_IPAMichel

echo "making template fcl"
make_template_fcl.py --BB=${BB} --release=${OUTRELEASE}${OUTVERSION}  --tag=${TAG} --verbose=${VERBOSE} --rue=${RMUE} --livetime=${LIVETIME} --run=${RUN} --dioemin=${DIO_EMIN} --rpcemin=${RPC_EMIN} --rmcemin=${RMC_EMIN} --ipaemin=${IPA_EMIN} --tmin=${TMIN} --samplingseed=${SAMPLINGSEED} --prc "DIO" "${GEN}Cosmic" "RPCInternal" "RPCExternal" "RMCInternal" "RMCExternal" "IPAMichel"

##### Below is genEnsemble and Grid:
echo "remove old files"
rm cnf.sophie.ensemble${TAG}.${INRELEASE}${INVERSION}.0.tar
rm filenames_${GEN}Cosmic_${NJOBS}.txt
rm filenames_DIO_${NJOBS}.txt
rm filenames_RPCInternal_${NJOBS}.txt
rm filenames_RPCExternal_${NJOBS}.txt
rm filenames_RMCInternal_${NJOBS}.txt
rm filenames_RMCExternal_${NJOBS}.txt
rm filenames_IPAMichel_${NJOBS}.txt

echo "get NJOBS files and list"
samweb list-files "dh.dataset=dts.mu2e.Cosmic${GEN}SignalAll.${COSMICTAG}.art" | head -${NJOBS} > filenames_${GEN}Cosmic_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.DIOtail_${DIO_EMIN}.${INRELEASE}${INVERSION}.art"  | head -${NJOBS} > filenames_DIO_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RPCInternal.${INRELEASE}${INVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RPCInternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RPCExternal.${INRELEASE}${INVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RPCExternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RMCInternal.${INRELEASE}${INVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RMCInternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.RMCExternal.${INRELEASE}${INVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_RMCExternal_${NJOBS}.txt
samweb list-files "dh.dataset=dts.mu2e.IPAMichel.${INRELEASE}${INVERSION}.art  and availability:anylocation"  | head -${NJOBS}  >  filenames_IPAMichel_${NJOBS}.txt


DSCONF=${OUTRELEASE}${OUTVERSION}
# note change setup to code to use a custom tarball
echo "run mu2e jobdef"
cmd="mu2ejobdef --desc=ensemble${TAG} --dsconf=${DSCONF} --run=${RUN} --setup ${SETUP} --sampling=1:DIO:filenames_DIO_${NJOBS}.txt --sampling=1:${GEN}Cosmic:filenames_${GEN}Cosmic_${NJOBS}.txt --sampling=1:RPCInternal:filenames_RPCInternal_${NJOBS}.txt  --embed SamplingInput_sr0.fcl  --sampling=1:RPCExternal:filenames_RPCExternal_${NJOBS}.txt --sampling=1:RMCInternal:filenames_RMCInternal_${NJOBS}.txt --sampling=1:IPAMichel:filenames_IPAMichel_${NJOBS}.txt--verb "
echo "Running: $cmd"
$cmd
parfile=$(ls cnf.*.tar)
# Remove cnf.
index_dataset=${parfile:4}
# Remove .0.tar
index_dataset=${index_dataset::-6}

idx=$(mu2ejobquery --njobs cnf.*.tar)
idx_format=$(printf "%07d" $idx)
echo $idx
echo "Creating index definiton with size: $idx"
samweb create-definition idx_${index_dataset} "dh.dataset etc.mu2e.index.000.txt and dh.sequencer < ${idx_format}"
echo "Created definiton: idx_${index_dataset}"
samweb describe-definition idx_${index_dataset}

echo "submit jobs"
cmd="mu2ejobsub --jobdef cnf.${OWNER}.ensemble${TAG}.${INRELEASE}${OUTVERSION}.0.tar --firstjob=0 --njobs=${NJOBS}  --default-protocol ifdh --default-location tape"
echo "Running: $cmd"
$cmd

# upload to SAM/tape:
#printJson --no-parents cnf.sophie.ensemble${TAG}.${INRELEASE}${INVERSION}.0.tar > cnf.sophie.ensemble${TAG}.${INRELEASE}${INVERSION}.0.tar.json
#ls *.json | mu2eFileDeclare
#ls *.tar| mu2eFileUpload --tape

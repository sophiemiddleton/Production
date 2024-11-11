#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g.  Stage1_makeinputs.sh --cosmics MDC2020ae --dem_emin 95 --rmue 1e-13 --BB 1BB --tag MDS1a --tmin 350

"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
COSMICS=""
NJOBS=1
LIVETIME="" #seconds
DEM_EMIN=95
BB=1BB
RMUE=1e-13
TMIN=0
TAG="MDS1a_test"
STOPS="MDC2020p"
RELEASE="MDC2020"
VERSION="ai"
# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        njobs)
          NJOBS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        cosmics)
          COSMICS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        livetime)
          LIVETIME=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        dem_emin)
          DEM_EMIN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        BB)
          BB=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rmue)
          RMUE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        tmin)
          TMIN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        tag)
          TAG=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        stops)
          STOPS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        release)
          RELEASE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        version)
          VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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

rm ${TAG}.txt
rm ${COSMICS}

echo "accessing files, making file lists"
mu2eDatasetFileList "dts.mu2e.CosmicCORSIKASignalAll.${COSMICS}.art" | head -${NJOBS} > ${COSMICS}


echo -n "njobs= " >> ${TAG}.txt
wc -l ${COSMICS} | awk '{print $1}' >> ${TAG}.txt
echo "cosmicjob=" ${COSMICS} >> ${TAG}.txt
echo "primaries=" ${RELEASE}${VERSION} >> ${TAG}.txt
echo "rmue=" ${RMUE} >> ${TAG}.txt
echo "dem_emin=" ${DEM_EMIN} >> ${TAG}.txt
echo "stops= " ${STOPS} >> ${TAG}.txt

mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S ${COSMICS} | grep 'Livetime:' | awk -F: '{print $NF}' > ${COSMICS}.livetime
LIVETIME=$(awk '{sum += $1} END {print sum}' ${COSMICS}.livetime)

echo "livetime=" ${LIVETIME} >> ${TAG}.txt
echo "BB=" ${BB} >> ${TAG}.txt
calculateEvents.py --livetime ${LIVETIME} --BB ${BB} --printpot "print" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --rue ${RMUE} --prc "CEMLL" --BB ${BB} --printpot "no">> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME}  --dem_emin ${DEM_EMIN} --prc "DIO" --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "CORSIKA" --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "RPC" --tmin ${TMIN} --internalrpc 1  --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "RPC" --tmin ${TMIN} --internalrpc 0  --BB ${BB} --printpot "no" >> ${TAG}.txt
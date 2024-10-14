#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g.  Stage1_makeinputs.sh --livetime 60000 --dem_emin 95 --rmue 1e-13 --BB 1BB --tag MDS1a

"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
COSMICS="MDC2020ae"
STOPS="MDC2020p"
NJOBS=""
LIVETIME="" #seconds
DEM_EMIN=""
BB=""
RMUE=""
TAG=""

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
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
        tag)
          TAG=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        stops)
          STOPS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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
mu2eDatasetFileList "dts.mu2e.CosmicCORSIKASignalAll.${COSMICS}.art"  > ${COSMICS}

mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S ${COSMICS} | grep 'Livetime:' | awk -F: '{print $NF}' > ${COSMICS}.livetime
TOTALLIVETIME=$(awk '{sum += $1} END {print sum}' ${COSMICS}.livetime)

var=${TOTALLIVETIME}/${LIVETIME}
echo -n "njobs= "  >> ${TAG}.txt
echo $(awk  'BEGIN { rounded = sprintf("%.0f", '${var}'); print rounded }')>> ${TAG}.txt

echo "rmue=" ${RMUE} >> ${TAG}.txt
echo "dem_emin=" ${DEM_EMIN} >> ${TAG}.txt
echo "stops=" ${STOPS} >> ${TAG}.txt
echo "cosmics=" ${COSMICS} >> ${TAG}.txt
echo "livetime=" ${LIVETIME} >> ${TAG}.txt
echo "totalLtime=" ${TOTALLIVETIME} >> ${TAG}.txt
echo "BB=" ${BB} >> ${TAG}.txt

# get yields:
calculateEvents.py --livetime ${LIVETIME} --BB ${BB} --printpot "print" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --rue ${RMUE} --prc "CEMLL" --BB ${BB} --printpot "no">> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME}  --dem_emin ${DEM_EMIN} --prc "DIO" --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "CORSIKA" --BB ${BB} --printpot "no" >> ${TAG}.txt

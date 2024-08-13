#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g.  Stage1_makeinputs.sh --cosmics filenames_CORSIKACosmic --dem_emin 95 --rmue 1e-13 --BB 1BB --tag MDS1a

"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
COSMICS=""
NJOBS=5
LIVETIME="" #seconds
DEM_EMIN=95
BB=1BB
RMUE=1e-13
RELEASE="MDC2024"
VERSION="a_sm4"
tag="MDS1a_test"
stops="MDC2020p"
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

rm ${tag}.txt
rm filenames_CORSIKACosmic
rm filenames_DIO
rm filenames_CeMLL

echo "accessing files, making file lists"
mu2eDatasetFileList "dts.mu2e.CosmicCORSIKASignalAll.MDC2020ae.art" | head -${NJOBS} > filenames_CORSIKACosmic
mu2eDatasetFileList "dts.mu2e.DIOtailp${DEM_EMIN}MeVc.${RELEASE}${VERSION}.art"| head -${NJOBS} > filenames_DIO
mu2eDatasetFileList "dts.mu2e.CeMLeadingLog.${RELEASE}${VERSION}.art" | head -${NJOBS} > filenames_CeMLL

echo -n "njobs= " >> ${tag}.txt
wc -l ${COSMICS} | awk '{print $1}' >> ${tag}.txt


echo "rmue=" ${RMUE} >> ${tag}.txt
echo "dem_emin=" ${DEM_EMIN} >> ${tag}.txt
echo "stops=MDC2020p" >> ${tag}.txt

mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S ${COSMICS} | grep 'Livetime:' | awk -F: '{print $NF}' > ${COSMICS}.livetime
LIVETIME=$(awk '{sum += $1} END {print sum}' ${COSMICS}.livetime)

echo "livetime=" ${LIVETIME} >> ${tag}.txt
echo "BB=" ${BB} >> ${tag}.txt
calculateEvents.py --livetime ${LIVETIME} --BB ${BB} --printpot "print" >> ${tag}.txt

calculateEvents.py --livetime ${LIVETIME} --rue ${RMUE} --prc "CEMLL" --BB ${BB} --printpot "no">> ${tag}.txt

calculateEvents.py --livetime ${LIVETIME}  --dem_emin ${DEM_EMIN} --prc "DIO" --BB ${BB} --printpot "no" >> ${tag}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "CORSIKA" --BB ${BB} --printpot "no" >> ${tag}.txt
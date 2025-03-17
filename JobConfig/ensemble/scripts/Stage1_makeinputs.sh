#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g.  Stage1_makeinputs.sh --cosmics MDC2020ae --dem_emin 95 --BB 1BB --tag MDS1a --tmin 350

"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
COSMICS="MDC2020ae"
NJOBS=1
LIVETIME="" #seconds
DEM_EMIN=95
BB=1BB
TMIN=350
TAG="MDS2a_test"
STOPS="MDC2020p"
RELEASE="MDC2020"
VERSION="ar"
GEN="CRY" #cosmic generator name CRY or CORSIKA only
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
        gen)
          GEN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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
mu2eDatasetFileList "dts.mu2e.Cosmic${GEN}SignalAll.${COSMICS}.art" | head -${NJOBS} > ${COSMICS}


echo -n "njobs= " >> ${TAG}.txt
wc -l ${COSMICS} | awk '{print $1}' >> ${TAG}.txt
echo "CosmicJob=" ${COSMICS} >> ${TAG}.txt
echo "CosmicGen=" ${GEN} >> ${TAG}.txt
echo "primaries=" ${RELEASE}${VERSION} >> ${TAG}.txt
#echo "DIO_emin=" ${DEM_EMIN} >> ${TAG}.txt
echo "stops= " ${STOPS} >> ${TAG}.txt

mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S ${COSMICS} | grep 'Livetime:' | awk -F: '{print $NF}' > ${COSMICS}.livetime
LIVETIME=$(awk '{sum += $1} END {print sum}' ${COSMICS}.livetime)
# note new use of the cosmics as a whole, assuming everything is "onspill" and using the duty factor in POT only
echo "onspilltime=" ${LIVETIME} >> ${TAG}.txt
echo "BB=" ${BB} >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc ${GEN} --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --BB ${BB} --printpot "print" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "IPAMichel" --BB ${BB} --ipaemin 70 --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME}  --dioemin ${DEM_EMIN} --prc "DIO" --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "RPC" --tmin ${TMIN} --internal 1 --rpcemin 50 --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "RPC" --tmin ${TMIN} --internal 0  --rpcemin 50 --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "RMC" --tmin ${TMIN} --internal 1  --rmcemin 85 --BB ${BB} --printpot "no" >> ${TAG}.txt

calculateEvents.py --livetime ${LIVETIME} --prc "RMC" --tmin ${TMIN} --internal 0  --rmcemin 85 --BB ${BB} --printpot "no" >> ${TAG}.txt



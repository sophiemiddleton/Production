#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g.  Stage1_initate_ensemble.sh --cosmics MDC2025ac --dem_emin 95 --BB 1BB --tag MDS3c --tmin 350

"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
COSMICS="MDC2025ac"
NJOBS=50
LIVETIME="" #seconds
DEM_EMIN=95
BB=1BB
TMIN=350
TAG="MDS3c"
STOPS="MDC2025ac"
RELEASE="MDC2025"
VERSION="ac"
GEN="Signal" #cosmic generator name CRY or CORSIKA only Cat = "Signal"
INCLUDE_RMCN0=1 # Include RMC 0N processes (default: no)
INCLUDE_RMCN1=1 # Include RMC 1N processes (default: no)
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
        rmcn0)
          INCLUDE_RMCN0=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rmcn1)
          INCLUDE_RMCN1=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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

rm -f ${TAG}.txt
rm -f ${COSMICS}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 Stage 1: Generate Input Configuration for Ensemble"
echo "   Tag: ${TAG} | Cosmics: Cosmic${GEN} | Dataset: ${COSMICS}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📁 [1/4] Accessing cosmic ray file lists..."
echo "   Dataset: dts.mu2e.Cosmic${GEN}.${COSMICS}.art"
echo "   Number of jobs: ${NJOBS}"
mu2eDatasetFileList "dts.mu2e.Cosmic${GEN}.${COSMICS}.art" | head -${NJOBS} > ${COSMICS}

# Get number of jobs
NUM_JOBS=$(wc -l ${COSMICS} | awk '{print $1}')
echo "   ✓ Retrieved ${NUM_JOBS} file(s)"
echo ""

echo "⏱️  [2/4] Calculating livetime from cosmic ray events...this may take some time depending on the number of files and their size..."
mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S ${COSMICS} | grep 'Livetime:' | awk -F: '{print $NF}' > ${COSMICS}.livetime
LIVETIME=$(awk '{sum += $1} END {print sum}' ${COSMICS}.livetime)
echo "   ✓ Total livetime: ${LIVETIME} seconds"
echo ""

echo "📊 [3/4] Computing beam parameters and event yields..."
echo "   Mode: ${BB} | DEM_emin: ${DEM_EMIN} | TMIN: ${TMIN}"
echo "   Calculating POT and normalization..."

BEAM_INFO=$(calculateEvents.py --livetime ${LIVETIME} --BB ${BB} --printpot "print" --verbose false 2>/dev/null)
# Extract POT details as individual variables
BEAM_ONSPILL_TIME=$(echo "${BEAM_INFO}" | grep "on_spill_time=" | awk '{print $NF}')
BEAM_LIVETIME=$(echo "${BEAM_INFO}" | grep "livetime=" | awk '{print $NF}')
BEAM_NPOT=$(echo "${BEAM_INFO}" | grep "^NPOT=" | awk '{print $NF}')
BEAM_NMOT=$(echo "${BEAM_INFO}" | grep "^NMOT=" | awk '{print $NF}')
#BEAM_POT=$(echo "${BEAM_INFO}" | grep "^POT=" | awk '{print $NF}')
echo "      • POT: ${BEAM_POT}"
# Energy cut parameters (hardcoded for now)
RPC_EMIN=50
RMC_N0_EMIN=80
RMC_N1_EMIN=80
RMC_kmax=90.1
IPA_EMIN=70
# Extract just the numeric values from event yields (remove labels and spaces)
echo "      • Calculating DIO events (emin=${DEM_EMIN})..."
DIO_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "DIO" --BB ${BB} --dioemin ${DEM_EMIN} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
echo "      • Calculating IPA Michel events (emin=${IPA_EMIN})..."
IPA_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "IPAMichel" --BB ${BB} --ipaemin ${IPA_EMIN} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
echo "      • Calculating RPC Internal events (emin=${RPC_EMIN})..."
RPC_INTERNAL_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "RPC" --tmin ${TMIN} --internal 1 --rpcemin ${RPC_EMIN} --BB ${BB} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
echo "      • Calculating RPC External events (emin=${RPC_EMIN})..."
RPC_EXTERNAL_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "RPC" --tmin ${TMIN} --internal 0 --rpcemin ${RPC_EMIN} --BB ${BB} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
if [[ ${INCLUDE_RMCN0} -eq 1 ]]; then
  echo "      • Calculating RMC 0N External events (emin=${RMC_N0_EMIN})..."
  RMC_N0_EXTERNAL_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "RMCPhaseSpace0NExternal" --internal 0 --rmcn0emin ${RMC_N0_EMIN} --BB ${BB} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
  echo "      • Calculating RMC 0N Internal events (emin=${RMC_N0_EMIN})..."
  RMC_N0_INTERNAL_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "RMCPhaseSpace0NInternal" --internal 1 --rmcn0emin ${RMC_N0_EMIN} --BB ${BB} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
fi
if [[ ${INCLUDE_RMCN1} -eq 1 ]]; then
  echo "      • Calculating RMC 1N External events (emin=${RMC_N1_EMIN})..."
  RMC_N1_EXTERNAL_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "RMCPhaseSpace1NExternal" --internal 0 --rmcn1emin ${RMC_N1_EMIN} --BB ${BB} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
  echo "      • Calculating RMC 1N Internal events (emin=${RMC_N1_EMIN})..."
  RMC_N1_INTERNAL_EVENTS=$(calculateEvents.py --livetime ${LIVETIME} --prc "RMCPhaseSpace1NInternal" --internal 1 --rmcn1emin ${RMC_N1_EMIN} --BB ${BB} --printpot "no" --verbose false 2>/dev/null | tail -1 | awk '{print $NF}')
fi
echo "   ✓ All event yields calculated"
echo ""
echo "💾 [4/4] Writing configuration file..."
echo "   Output: ${TAG}.txt"

# Write configuration in shell-sourceable format
{
  echo "# Configuration file for ensemble ${TAG}"
  echo "# Generated by Stage1_initate_ensemble.sh"
  echo "njobs=\"${NUM_JOBS}\""
  echo "CosmicJob=\"${COSMICS}\""
  echo "CosmicGen=\"${GEN}\""
  echo "primaries=\"${RELEASE}${VERSION}\""
  echo "muon_stops=\"${STOPS}\""
  echo "onspilltime=\"${LIVETIME}\""
  echo "BB=\"${BB}\""
  echo "DEM_emin=\"${DEM_EMIN}\""
  echo "RPC_TMIN=\"${TMIN}\""
  echo "RPC_emin=\"${RPC_EMIN}\""
  if [[ ${INCLUDE_RMCN0} -eq 1 ]]; then
    echo "RMC_N0_emin=\"${RMC_N0_EMIN}\""
  fi
  if [[ ${INCLUDE_RMCN1} -eq 1 ]]; then
    echo "RMC_N1_emin=\"${RMC_N1_EMIN}\""
  fi
  echo "RMC_kmax=\"${RMC_kmax}\""
  echo "IPA_emin=\"${IPA_EMIN}\"" 
  echo ""
  echo "# ===== POT Calculation Details ====="
  echo "beam_onspill_time=\"${BEAM_ONSPILL_TIME}\""
  echo "beam_livetime=\"${BEAM_LIVETIME}\""
  echo "beam_npot=\"${BEAM_NPOT}\""
  echo "beam_nmot=\"${BEAM_NMOT}\""
  echo "beam_pot=\"${BEAM_POT}\""
  echo ""
  echo "# ===== Event Yields (counts) ====="
  echo "dio_events=\"${DIO_EVENTS}\""
  echo "ipa_events=\"${IPA_EVENTS}\""
  echo "rpc_internal_events=\"${RPC_INTERNAL_EVENTS}\""
  echo "rpc_external_events=\"${RPC_EXTERNAL_EVENTS}\""
  if [[ ${INCLUDE_RMCN0} -eq 1 ]]; then
    echo "rmc_n0_internal_events=\"${RMC_N0_INTERNAL_EVENTS}\""
    echo "rmc_n0_external_events=\"${RMC_N0_EXTERNAL_EVENTS}\""
  fi
  if [[ ${INCLUDE_RMCN1} -eq 1 ]]; then
    echo "rmc_n1_internal_events=\"${RMC_N1_INTERNAL_EVENTS}\""
    echo "rmc_n1_external_events=\"${RMC_N1_EXTERNAL_EVENTS}\""
  fi
} > ${TAG}.txt

echo "   ✓ Configuration file written successfully"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Stage 1 Complete!"
echo "   Config file: ${TAG}.txt"
echo "   Ready for Stage 2: Stage2_build_sampler.sh --tag ${TAG}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

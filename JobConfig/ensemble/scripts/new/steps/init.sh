#!/usr/bin/bash
# Stage 1: write the tag's manifest (config, livetime, expected yields).
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh init --tag <TAG> --version <letters> --livetime <s> [options]
  e.g. mds.sh init --tag MDS4a --version ax --livetime 5.72e6 --type physics --BB 1BB

Required:
  --tag         MDS tag, e.g. MDS4a
  --version     SimJob version letters, e.g. ax (-> ${RELEASE:-MDC2025}ax); set once here, used by every step
  --livetime    cosmic livetime [s] (see https://mu2ewiki.fnal.gov/wiki/MDC2025#Cosmics)
                or --compute-livetime to sum printCosmicLivetime over the chosen files
                (note: resampled cosmics carry the CosmicLivetime integer-division bug)

Options (defaults in brackets):
  --release MDC2025       --type physics|trigger [physics: DEM_emin 95; trigger: 75]
  --BB 1BB                --tmin 350               --njobs N [all cosmic files]
  --cosmics <REL+ver>     cosmics dataset version, e.g. MDC2025ac [latest dts.mu2e.CosmicSignal]
  --stops MDC2025ac       --rmcn0 1|0 [1]          --rmcn1 1|0 [0]
  --rpc-emin 50  --rmc-n0-emin 80  --rmc-n1-emin 80  --rmc-kmax 90.1  --ipa-emin 70
  --owner mu2e            --run 1430               --samplingseed 1
  --dbpurpose Sim_best    --dbversion v1_1         --anaversion v02_02_00
  --ntuple-dsconf <REL>-001
  --workroot DIR [\$MDS_WORKROOT or cwd]   --force (overwrite an existing manifest)
EOF
}

RELEASE="MDC2025"; VERSION=""; LIVETIME=""; COMPUTE_LT=0
TYPE="physics"; BB="1BB"; TMIN=350; NJOBS=""; COSMICS=""; STOPS="MDC2025ac"
INCLUDE_RMCN0=1; INCLUDE_RMCN1=0   # RMC 1N off by default until its samples are fixed
RPC_EMIN=50; RMC_N0_EMIN=80; RMC_N1_EMIN=80; RMC_KMAX=90.1; IPA_EMIN=70
OWNER="mu2e"; RUN=1430; SAMPLINGSEED=1
DBPURPOSE="Sim_best"; DBVERSION="v1_1"; ANAVERSION="v02_02_00"; NTUPLE_DSCONF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)        RELEASE=$(optval "$@"); shift 2 ;;
    --version)        VERSION=$(optval "$@"); shift 2 ;;
    --livetime)       LIVETIME=$(optval "$@"); shift 2 ;;
    --compute-livetime) COMPUTE_LT=1; shift ;;
    --type)           TYPE=$(optval "$@"); shift 2 ;;
    --BB)             BB=$(optval "$@"); shift 2 ;;
    --tmin)           TMIN=$(optval "$@"); shift 2 ;;
    --njobs)          NJOBS=$(optval "$@"); shift 2 ;;
    --cosmics)        COSMICS=$(optval "$@"); shift 2 ;;
    --stops)          STOPS=$(optval "$@"); shift 2 ;;
    --rmcn0)          INCLUDE_RMCN0=$(optval "$@"); shift 2 ;;
    --rmcn1)          INCLUDE_RMCN1=$(optval "$@"); shift 2 ;;
    --rpc-emin)       RPC_EMIN=$(optval "$@"); shift 2 ;;
    --rmc-n0-emin)    RMC_N0_EMIN=$(optval "$@"); shift 2 ;;
    --rmc-n1-emin)    RMC_N1_EMIN=$(optval "$@"); shift 2 ;;
    --rmc-kmax)       RMC_KMAX=$(optval "$@"); shift 2 ;;
    --ipa-emin)       IPA_EMIN=$(optval "$@"); shift 2 ;;
    --owner)          OWNER=$(optval "$@"); shift 2 ;;
    --run)            RUN=$(optval "$@"); shift 2 ;;
    --samplingseed)   SAMPLINGSEED=$(optval "$@"); shift 2 ;;
    --dbpurpose)      DBPURPOSE=$(optval "$@"); shift 2 ;;
    --dbversion)      DBVERSION=$(optval "$@"); shift 2 ;;
    --anaversion)     ANAVERSION=$(optval "$@"); shift 2 ;;
    --ntuple-dsconf)  NTUPLE_DSCONF=$(optval "$@"); shift 2 ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done

[[ -n ${VERSION} ]] || { usage; die "--version is required"; }
[[ -n ${LIVETIME} || ${COMPUTE_LT} -eq 1 ]] || { usage; die "--livetime (or --compute-livetime) is required"; }
[[ -z ${LIVETIME} ]] || is_number "${LIVETIME}" || die "--livetime must be a number, got '${LIVETIME}'"
case "${TYPE}" in
  physics) DEM_EMIN=95 ;;
  trigger) DEM_EMIN=75 ;;
  *) die "--type must be 'physics' or 'trigger', got '${TYPE}'" ;;
esac
NTUPLE_DSCONF=${NTUPLE_DSCONF:-${RELEASE}-001}

[[ -n ${TAG} ]] || die "--tag is required"
if [[ -f "${WORKROOT}/${TAG}/manifest.env" ]] && (( ! FORCE )); then
  die "${WORKROOT}/${TAG}/manifest.env already exists; use --force to start this tag over"
fi
enter_workdir init 1
require_cmds samweb mu2eDatasetFileList python3
header "🚀 Stage 1 (init): configuration and expected yields"
rm -f "${MANIFEST}"
mkdir -p lists

# ---------------------------------------------------------------- cosmics
if [[ -z ${COSMICS} ]]; then
  log "🔍 [1/4] Finding latest dts.mu2e.CosmicSignal.${RELEASE}<version>.art..."
  v=$(discover_version "dts.mu2e.CosmicSignal%.${RELEASE}%.art")
  [[ -n ${v} ]] || die "could not find a CosmicSignal dataset for ${RELEASE}; pass --cosmics"
  COSMICS="${RELEASE}${v}"
else
  log "🔍 [1/4] Using cosmics ${COSMICS}"
fi
COSMIC_DS="dts.mu2e.CosmicSignal.${COSMICS}.art"
mu2eDatasetFileList "${COSMIC_DS}" > lists/CRYCosmic.all
sort_by_basename lists/CRYCosmic.all > lists/CRYCosmic.sorted
n_avail=$(wc -l < lists/CRYCosmic.sorted)
(( n_avail > 0 )) || die "no files in ${COSMIC_DS}"
if [[ -z ${NJOBS} ]]; then
  NJOBS=${n_avail}
elif (( NJOBS > n_avail )); then
  die "--njobs ${NJOBS} but ${COSMIC_DS} has only ${n_avail} files"
fi
head -n "${NJOBS}" lists/CRYCosmic.sorted > lists/CRYCosmic.chosen
ok "${COSMIC_DS}: using ${NJOBS} of ${n_avail} files (lists/CRYCosmic.chosen)"
log ""

# ---------------------------------------------------------------- livetime
log "⏱️  [2/4] Livetime..."
if (( COMPUTE_LT )); then
  require_cmds mu2e
  warn "computing livetime with printCosmicLivetime (may be slow)"
  mu2e -c Offline/Print/fcl/printCosmicLivetime.fcl -S lists/CRYCosmic.chosen \
    | { grep 'Livetime:' || true; } | awk -F: '{ print $NF }' > lists/CRYCosmic.livetime
  LIVETIME=$(awk '{ s += $1 } END { print s + 0 }' lists/CRYCosmic.livetime)
  [[ ${LIVETIME} != 0 ]] || die "printCosmicLivetime returned no livetime"
fi
ok "livetime: ${LIVETIME} s"
if (( ! COMPUTE_LT && NJOBS < n_avail )); then
  warn "using ${NJOBS} of ${n_avail} cosmic files: make sure --livetime is the livetime of those ${NJOBS} files"
fi
log ""

# ---------------------------------------------------------------- yields
log "📊 [3/4] Computing POT and expected yields (BB=${BB}, DEM_emin=${DEM_EMIN}, tmin=${TMIN})..."
rmcn0=""; rmcn1=""
(( INCLUDE_RMCN0 )) && rmcn0=${RMC_N0_EMIN}
(( INCLUDE_RMCN1 )) && rmcn1=${RMC_N1_EMIN}
YIELDS=$(python3 "${NEW_DIR}/lib/yields.py" background --livetime "${LIVETIME}" --BB "${BB}" \
  --dioemin "${DEM_EMIN}" --ipaemin "${IPA_EMIN}" --rpcemin "${RPC_EMIN}" --tmin "${TMIN}" \
  --rmcn0emin "${rmcn0}" --rmcn1emin "${rmcn1}") || die "yield calculation failed"
log "${YIELDS}" | sed 's/^/      • /'
log ""

# ---------------------------------------------------------------- manifest
log "💾 [4/4] Writing ${MANIFEST}..."
DSCONF="${RELEASE}${VERSION}_${TAG}"
DB_TAG="${DBPURPOSE#Sim_}_${DBVERSION}"          # Sim_best + v1_1 -> best_v1_1
{
  echo "# Manifest for MDS ${TAG}. Written by mds.sh; edit with care."
  echo "# ===== Workflow ====="
} > "${MANIFEST}"
manifest_set tag            "${TAG}"
manifest_set release        "${RELEASE}"
manifest_set version        "${VERSION}"
manifest_set owner          "${OWNER}"
manifest_set run            "${RUN}"
manifest_set samplingseed   "${SAMPLINGSEED}"
manifest_set simjob_setup   "/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${RELEASE}${VERSION}/setup.sh"
manifest_set dbpurpose      "${DBPURPOSE}"
manifest_set dbversion      "${DBVERSION}"
manifest_set anaversion     "${ANAVERSION}"
manifest_set dsconf         "${DSCONF}"
manifest_set dsconf_digi    "${DSCONF}_${DB_TAG}"
manifest_set ntuple_dsconf  "${NTUPLE_DSCONF}_${TAG}"
manifest_set ds_dts         "dts.mu2e.ensemble.${DSCONF}.art"
manifest_set ds_dig         "dig.mu2e.ensembleOnSpill.${DSCONF}_${DB_TAG}.art"
manifest_set ds_mcs         "mcs.mu2e.ensembleOnSpillReco.${DSCONF}_${DB_TAG}.art"
manifest_set ds_nts         "nts.mu2e.ensembleNtuple.${NTUPLE_DSCONF}_${TAG}.root"
echo "# ===== Configuration (same keys as Stage1's <TAG>.txt) =====" >> "${MANIFEST}"
manifest_set type           "${TYPE}"
manifest_set njobs          "${NJOBS}"
manifest_set CosmicJob      "${COSMICS}"
manifest_set CosmicGen      "Signal"
manifest_set muon_stops     "${STOPS}"
manifest_set onspilltime    "${LIVETIME}"
manifest_set BB             "${BB}"
manifest_set DEM_emin       "${DEM_EMIN}"
manifest_set RPC_TMIN       "${TMIN}"
manifest_set RPC_emin       "${RPC_EMIN}"
(( INCLUDE_RMCN0 )) && manifest_set RMC_N0_emin "${RMC_N0_EMIN}"
(( INCLUDE_RMCN1 )) && manifest_set RMC_N1_emin "${RMC_N1_EMIN}"
manifest_set RMC_kmax       "${RMC_KMAX}"
manifest_set IPA_emin       "${IPA_EMIN}"
echo "# ===== POT and expected yields =====" >> "${MANIFEST}"
manifest_merge <<<"${YIELDS}"
echo "# ===== Step state =====" >> "${MANIFEST}"
step_done init

log ""
log "═══════════════════════════════════════════════════════════════"
log "✅ init complete. Manifest: ${MANIFEST}"
log "   Next: mds.sh build --tag ${TAG} --workroot ${WORKROOT}"
log "═══════════════════════════════════════════════════════════════"

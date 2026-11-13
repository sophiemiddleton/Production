#!/usr/bin/bash
# Stage 5: for each pseudo-experiment, split off the right number of signal
# events, ntuple them, and build a shuffled list of signal + known-physics ntuples.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh signal --tag <TAG> --signal <name> [--signalmcs <dataset>] [options]
  e.g. mds.sh signal --tag MDS4a --signal CeMLeadingLog --rate 1e-13 --nexp 3

Required:
  --signal NAME        signal process, e.g. CeMLeadingLog. The digi mode (OnSpill or
                       Mix<N>BB) is taken from the MDS unless NAME includes one; add
                       Triggered to prefer triggered samples.
Options:
  --signalmcs DS       reconstructed signal dataset (mcs.mu2e.NAME.RELEASE_PURPOSE_VERSION.art)
                       [found in SAM: same release and digi mode as the MDS, preferring
                        its DB purpose/version, then its SimJob version, then the latest]
  --rate 1e-13         Rmue
  --nexp 1             number of pseudo-experiments
  --livetime S         use only S seconds of the known-physics livetime [all]
  --recoeff 0.4009075  signal reconstruction efficiency correction
  --merge 1            mcs files per known-physics ntuple file (the ntuple stage merge)
  --seed N             makes the signal yield and file choices reproducible (pe i uses N+i)
  --label NAME         output directory signal/NAME [<signal>_<rate>]
  --mdsfiles DS        known-physics ntuple dataset [manifest ds_nts]
  --dts-nfiles N       files in the MDS dts dataset, which sets the livetime per
                       ntuple file [from SAM; manifest ds_dts]
  --signal-ngen N      generated events in --signalmcs [from SAM]
  --owner NAME         owner field of the local output names [manifest owner]
  --force              redo an existing label
EOF
}

SIGNAL=""; SIGNALMCS=""; RATE=1e-13; NEXP=1; CHOOSE=""; RECOEFF=0.4009075; MERGE=1
SEED=""; LABEL=""; MDSFILES=""; DTS_NFILES=""; SIGNAL_NGEN=""; OWNER_OPT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --signal)       SIGNAL=$(optval "$@"); shift 2 ;;
    --signalmcs)    SIGNALMCS=$(optval "$@"); shift 2 ;;
    --rate)         RATE=$(optval "$@"); shift 2 ;;
    --nexp)         NEXP=$(optval "$@"); shift 2 ;;
    --livetime)     CHOOSE=$(optval "$@"); shift 2 ;;
    --recoeff)      RECOEFF=$(optval "$@"); shift 2 ;;
    --merge)        MERGE=$(optval "$@"); shift 2 ;;
    --seed)         SEED=$(optval "$@"); shift 2 ;;
    --label)        LABEL=$(optval "$@"); shift 2 ;;
    --mdsfiles)     MDSFILES=$(optval "$@"); shift 2 ;;
    --dts-nfiles)   DTS_NFILES=$(optval "$@"); shift 2 ;;
    --signal-ngen)  SIGNAL_NGEN=$(optval "$@"); shift 2 ;;
    --owner)        OWNER_OPT=$(optval "$@"); shift 2 ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done
[[ -n ${SIGNAL} ]]    || { usage; die "--signal is required"; }
[[ ${NEXP} =~ ^[1-9][0-9]*$ ]] || die "--nexp must be a positive integer"
for v in RATE RECOEFF MERGE; do is_number "${!v}" || die "--${v,,} must be a number"; done
[[ -z ${CHOOSE} ]] || is_number "${CHOOSE}" || die "--livetime must be a number"
[[ -z ${SEED} || ${SEED} =~ ^[0-9]+$ ]] || die "--seed must be a non-negative integer"

enter_workdir signal
require_step digireco
manifest_require beam_livetime BB duty_factor owner ds_nts ds_dts ds_dig release version dbpurpose dbversion
require_cmds samweb mu2eDatasetFileList samDatasetsSummary.sh mu2e python3
MDSFILES=${MDSFILES:-${ds_nts}}
OWNER=${OWNER_OPT:-${owner}}
LABEL=${LABEL:-${SIGNAL}_${RATE}}
[[ ${LABEL} =~ ^[A-Za-z0-9._+-]+$ ]] || die "--label may only contain letters, digits and ._+-"
OUT="${WORKDIR}/signal/${LABEL}"
header "📡 Stage 5 (signal): ${SIGNAL} at Rmue=${RATE}, ${NEXP} pseudo-experiment(s) -> signal/${LABEL}"

if [[ -f ${OUT}/signal.env ]] && (( ! FORCE )); then
  die "signal/${LABEL} already exists; use --force to redo it or --label for a new one"
fi
rm -rf "${OUT}"
mkdir -p "${OUT}"

# ---------------------------------------------------------------- signal dataset
# Compatible means the same release and digi mode as the MDS (pileup or not),
# ideally with the same DB purpose/version so both share calibrations.
DB_TAG="${dbpurpose#Sim_}_${dbversion}"          # Sim_best + v1_1 -> best_v1_1
MDS_MODE=""
[[ ${ds_dig} =~ ^dig\.mu2e\.ensemble(OnSpill|Mix[0-9]+BB)\. ]] && MDS_MODE=${BASH_REMATCH[1]}
[[ -n ${MDS_MODE} ]] || warn "cannot tell the MDS digi mode from ${ds_dig}; not matching on it"

# CeMLeadingLogMix1BBTriggered -> "CeMLeadingLog Mix1BB 1"; mode is - when absent
split_signal_name() {
  local n=$1 trig=0 mode=-
  [[ ${n} == *Triggered ]] && { trig=1; n=${n%Triggered}; }
  if [[ ${n} =~ ^(.+)(OnSpill|Mix[0-9]+BB)$ ]]; then n=${BASH_REMATCH[1]}; mode=${BASH_REMATCH[2]}; fi
  echo "${n} ${mode} ${trig}"
}

if [[ -z ${SIGNALMCS} ]]; then
  read -r SIG_BASE WANT_MODE WANT_TRIG <<<"$(split_signal_name "${SIGNAL}")"
  [[ ${WANT_MODE} != - ]] || WANT_MODE=${MDS_MODE}
  log "🔍 Finding mcs.mu2e.${SIG_BASE}${WANT_MODE}[Triggered].${release}<version>_<db>.art (MDS: ${release}${version}_${DB_TAG}, ${MDS_MODE:-mode unknown})..."
  # One line per candidate: DB match, Triggered match, same version, version length, version, dataset
  candidates=$(samweb list-definitions --defname="mcs.mu2e.${SIG_BASE}%.${release}%.art" 2>/dev/null || true)
  ranked=$(while read -r def; do
      [[ ${def} =~ ^mcs\.mu2e\.([A-Za-z0-9]+)\.${release}([a-z]+)_([A-Za-z]+_v[0-9]+(_[0-9]+)*)\.art$ ]] || continue
      name=${BASH_REMATCH[1]}; v=${BASH_REMATCH[2]}; db=${BASH_REMATCH[3]}
      read -r b m t <<<"$(split_signal_name "${name}")"
      [[ ${b} == "${SIG_BASE}" ]] || continue
      [[ -z ${WANT_MODE} || ${m} == "${WANT_MODE}" ]] || continue
      echo "$([[ ${db} == "${DB_TAG}" ]] && echo 1 || echo 0) $(( t == WANT_TRIG )) $([[ ${v} == "${version}" ]] && echo 1 || echo 0) ${#v} ${v} ${def}"
    done <<<"${candidates}" | sort -k1,4nr -k5,5r)
  SIGNALMCS=""
  while read -r _ _ _ _ _ def; do
    [[ -n ${def} ]] || continue
    if [[ $(dataset_count "${def}") =~ ^[1-9][0-9]*$ ]]; then SIGNALMCS=${def}; break; fi
  done <<<"${ranked}"
  if [[ -z ${SIGNALMCS} ]]; then
    log "   Signal mcs datasets for ${SIG_BASE} in SAM:"
    sed 's/^/      /' <<<"${candidates}"
    die "no ${release} ${WANT_MODE} signal for ${SIG_BASE} with files; pass --signal with another mode, or --signalmcs"
  fi
  ok "using ${SIGNALMCS}"
fi
# Name the outputs after the sample actually used
SIGNAL=${SIGNALMCS##*/}; SIGNAL=${SIGNAL#mcs.*.}; SIGNAL=${SIGNAL%%.*}

# mcs.mu2e.NAME.RELEASE_PURPOSE_VERSION.art -> RELEASE_PURPOSE_VERSION
SIG_DSCONF=${SIGNALMCS##*/}; SIG_DSCONF=${SIG_DSCONF%.art}; SIG_DSCONF=${SIG_DSCONF##*.}
[[ ${SIG_DSCONF} =~ ^[^_]+_[^_]+_.+$ ]] || die "cannot parse RELEASE_PURPOSE_VERSION from '${SIGNALMCS}'"
[[ ${SIG_DSCONF} == ${release}* ]] || warn "signal release ${SIG_DSCONF%%_*} differs from the MDS's ${release}${version}"
[[ ${SIG_DSCONF} == *_${DB_TAG} ]] || warn "signal DB ${SIG_DSCONF#*_} differs from the MDS's ${DB_TAG}"
read -r _ sig_mode sig_trig <<<"$(split_signal_name "${SIGNAL}")"
[[ ${sig_mode} != - ]] || sig_mode=""
if [[ -n ${MDS_MODE} && ${sig_mode} != "${MDS_MODE}" ]]; then
  warn "signal digi mode '${sig_mode:-unknown}' differs from the MDS's ${MDS_MODE} (pileup won't match)"
fi
(( sig_trig )) || warn "signal sample is not trigger-filtered"
log ""

# ---------------------------------------------------------------- livetime
log "⏱️  [1/4] Livetime and known-physics files..."
# Each ntuple file holds the livetime of digi_merge x --merge dts files. Use the
# ntuple files that actually exist, so files lost in digi/reco/ntuple reduce
# the livetime rather than being counted.
if [[ -n ${true_beam_livetime:-} ]]; then
  GEN_LIVETIME=${true_beam_livetime}
  ok "dts livetime ${GEN_LIVETIME} s (true_beam_livetime from validate)"
else
  GEN_LIVETIME=${beam_livetime}
  warn "no true_beam_livetime in the manifest (validate not run here); using the requested ${GEN_LIVETIME} s"
fi
DIGI_MERGE=${digi_merge:-100}
N_DTS=${DTS_NFILES:-$(dataset_count "${ds_dts}")}
[[ ${N_DTS} =~ ^[1-9][0-9]*$ ]] || die "could not count files in ${ds_dts}; pass --dts-nfiles"
N_NTS=$(dataset_count "${MDSFILES}")
[[ ${N_NTS} =~ ^[1-9][0-9]*$ ]] || die "could not count files in ${MDSFILES}"
DTS_PER_FILE=$(awk -v a="${DIGI_MERGE}" -v b="${MERGE}" 'BEGIN { print a * b }')
LIVETIME_PER_FILE=$(awk -v g="${GEN_LIVETIME}" -v d="${N_DTS}" -v m="${DTS_PER_FILE}" \
  'BEGIN { printf "%.0f", g * m / d }')
N_EXPECTED=$(awk -v d="${N_DTS}" -v m="${DTS_PER_FILE}" 'BEGIN { n = d / m; print (n == int(n)) ? n : int(n) + 1 }')
ok "${N_DTS} dts files / ${DTS_PER_FILE} per ntuple file -> ${N_EXPECTED} ntuple files expected, ${LIVETIME_PER_FILE} s each"
if (( N_NTS < N_EXPECTED )); then
  warn "${MDSFILES} has ${N_NTS} of ${N_EXPECTED} files ($(( N_EXPECTED - N_NTS )) lost); livetime scaled to match"
elif (( N_NTS > N_EXPECTED )); then
  warn "${MDSFILES} has ${N_NTS} files, more than the ${N_EXPECTED} expected; check digi_merge in the manifest and --merge"
fi
AVAIL_LIVETIME=$(awk -v n="${N_NTS}" -v p="${LIVETIME_PER_FILE}" 'BEGIN { printf "%.0f", n * p }')
LIVETIME=${AVAIL_LIVETIME}
if [[ -n ${CHOOSE} ]]; then
  if awk -v c="${CHOOSE}" -v a="${AVAIL_LIVETIME}" 'BEGIN { exit !(c > a) }'; then
    warn "--livetime ${CHOOSE} exceeds the ${AVAIL_LIVETIME} s available; using ${AVAIL_LIVETIME}"
  else
    LIVETIME=${CHOOSE}
  fi
fi
N_KNOWN=$(awk -v l="${LIVETIME}" -v p="${LIVETIME_PER_FILE}" 'BEGIN { printf "%.0f", l / p }')
(( N_KNOWN >= 1 )) || die "--livetime ${CHOOSE} is less than one ntuple file (${LIVETIME_PER_FILE} s)"
LIVETIME=$(awk -v n="${N_KNOWN}" -v p="${LIVETIME_PER_FILE}" 'BEGIN { printf "%.0f", n * p }')
ONSPILL=$(awk -v l="${LIVETIME}" -v d="${duty_factor}" 'BEGIN { printf "%.0f", l * d }')
ok "using ${N_KNOWN} of ${N_NTS} ntuple files -> livetime ${LIVETIME} s, on-spill ${ONSPILL} s (duty ${duty_factor})"
log ""

# ---------------------------------------------------------------- signal sample
log "📊 [2/4] Signal sample ${SIGNALMCS}..."
NGEN=${SIGNAL_NGEN:-$(dataset_generated "${SIGNALMCS}")}
[[ ${NGEN} =~ ^[1-9][0-9]*$ ]] || die "could not get generated events for ${SIGNALMCS}; pass --signal-ngen"
N_TOTAL_SIGNAL=$(dataset_count "${SIGNALMCS}")
[[ ${N_TOTAL_SIGNAL} =~ ^[1-9][0-9]*$ ]] || die "could not count files in ${SIGNALMCS}"
EVENTS_PER_FILE=$(awk -v g="${NGEN}" -v n="${N_TOTAL_SIGNAL}" 'BEGIN { printf "%.0f", g / n }')
ok "${NGEN} generated events in ${N_TOTAL_SIGNAL} files (~${EVENTS_PER_FILE} per file)"
log ""

log "📁 [3/4] File lists..."
mu2eDatasetFileList "${SIGNALMCS}" > "${OUT}/signal_all.txt"
mu2eDatasetFileList "${MDSFILES}"  > "${OUT}/known_all.txt"
n_known_avail=$(wc -l < "${OUT}/known_all.txt")
[[ -s ${OUT}/signal_all.txt ]] || die "no files for ${SIGNALMCS}"
(( n_known_avail >= N_KNOWN )) || die "${MDSFILES} has ${n_known_avail} files, ${N_KNOWN} needed"
ok "signal: $(wc -l < "${OUT}/signal_all.txt") files, known physics: ${n_known_avail} files"
log ""

{
  echo "# Signal set ${LABEL} for MDS ${TAG}. Written by mds.sh signal."
  echo "signal=\"${SIGNAL}\""
  echo "signalmcs=\"${SIGNALMCS}\""
  echo "mdsfiles=\"${MDSFILES}\""
  echo "Rmue=\"${RATE}\""
  echo "livetime_combined=\"${LIVETIME}\""
  echo "onspill_combined=\"${ONSPILL}\""
  echo "npseudo_experiments=\"${NEXP}\""
  echo "recoeff=\"${RECOEFF}\""
  echo "known_files_per_pe=\"${N_KNOWN}\""
  echo "seed=\"${SEED}\""
} > "${OUT}/signal.env.tmp"

# ---------------------------------------------------------------- pseudo-experiments
log "🎲 [4/4] Pseudo-experiments..."
for (( i = 1; i <= NEXP; i++ )); do
  pe="${OUT}/pe_${i}"; mkdir -p "${pe}"
  pe_seed=""; [[ -n ${SEED} ]] && pe_seed=$(( SEED + i ))
  log "  [${i}/${NEXP}]"
  NSIG_RAW=$(python3 "${NEW_DIR}/lib/yields.py" signal --livetime "${ONSPILL}" --BB "${BB}" --rue "${RATE}" \
    ${pe_seed:+--seed "${pe_seed}"} | sed -n 's/^nsig="\(.*\)"$/\1/p')
  [[ ${NSIG_RAW} =~ ^[0-9]+$ ]] || die "signal yield calculation failed"
  NSIG=$(awk -v n="${NSIG_RAW}" -v e="${RECOEFF}" 'BEGIN { printf "%.0f", n * e }')
  ok "signal events: ${NSIG_RAW} -> ${NSIG} after reco efficiency ${RECOEFF}"
  echo "nsig_${i}=\"${NSIG}\"" >> "${OUT}/signal.env.tmp"

  : > "${pe}/mixed_files.txt"
  if (( NSIG > 0 )); then
    nfiles=$(awk -v s="${NSIG}" -v e="${EVENTS_PER_FILE}" 'BEGIN { n = sprintf("%.0f", s / e); print (n < 1) ? 1 : n }')
    seeded_shuf "${pe_seed:+${pe_seed}-signal}" -n "${nfiles}" "${OUT}/signal_all.txt" > "${pe}/signal_files.txt"
    split_art="mcs.${OWNER}.${SIGNAL}Split.${SIG_DSCONF}.${i}.art"
    split_nts="nts.${OWNER}.${SIGNAL}Split.${SIG_DSCONF}.${i}.root"
    {
      echo '#include "Production/JobConfig/ensemble/fcl/split.fcl"'
      echo "source.fileNames: ["
      awk '{ printf "%s\"%s\"", (NR > 1 ? ",\n  " : "  "), $0 } END { print "" }' "${pe}/signal_files.txt"
      echo "]"
      echo "source.maxEvents: ${NSIG}"
      echo "outputs.out.fileName: \"${split_art}\""
    } > "${pe}/splitter.fcl"
    {
      echo '#include "EventNtuple/fcl/from_mcs-mockdata.fcl"'
      echo "services.TFileService.fileName: \"${split_nts}\""
    } > "${pe}/ntuple.fcl"
    ( cd "${pe}" && mu2e -c splitter.fcl > splitter.log 2>&1 ) || die "splitter failed; see ${pe}/splitter.log"
    [[ -f ${pe}/${split_art} ]] || die "splitter did not write ${pe}/${split_art}"
    ok "split ${NSIG} events from ${nfiles} file(s) -> ${split_art}"
    ( cd "${pe}" && mu2e -c ntuple.fcl -s "${split_art}" > ntuple.log 2>&1 ) || die "ntuple job failed; see ${pe}/ntuple.log"
    [[ -f ${pe}/${split_nts} ]] || die "ntuple job did not write ${pe}/${split_nts}"
    ok "ntuple -> ${split_nts}"
    echo "${pe}/${split_nts}" >> "${pe}/mixed_files.txt"
  else
    warn "no signal events in this pseudo-experiment; known physics only"
  fi
  seeded_shuf "${pe_seed:+${pe_seed}-known}" -n "${N_KNOWN}" "${OUT}/known_all.txt" >> "${pe}/mixed_files.txt"
  seeded_shuf "${pe_seed:+${pe_seed}-mix}" "${pe}/mixed_files.txt" > "${pe}/mixed_files.shuf" && mv "${pe}/mixed_files.shuf" "${pe}/mixed_files.txt"
  ok "pe_${i}/mixed_files.txt: $(wc -l < "${pe}/mixed_files.txt") files"
done
mv "${OUT}/signal.env.tmp" "${OUT}/signal.env"

log ""
log "═══════════════════════════════════════════════════════════════"
log "✅ signal complete: ${OUT}"
log "   Next: mds.sh mix --tag ${TAG} --workroot ${WORKROOT} --label ${LABEL}"
log "═══════════════════════════════════════════════════════════════"

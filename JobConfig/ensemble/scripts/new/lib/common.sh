#!/usr/bin/bash
# Shared helpers for the MDS (ensemble) workflow driven by mds.sh.
# Sourced by every step in steps/; not meant to be run directly.
#
# Each tag lives in its own working directory, <workroot>/<TAG>, holding a
# manifest.env that every step reads and adds to. The manifest is the single
# source of truth for release/version, cuts, yields, dataset names and which
# steps have finished.

set -euo pipefail

NEW_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENSEMBLE_DIR=$(cd "${NEW_DIR}/../.." && pwd)
ENSEMBLE_PY="${ENSEMBLE_PY:-${ENSEMBLE_DIR}/python}"
POMS_MAP="${POMS_MAP:-/exp/mu2e/app/users/mu2epro/production_manager/poms_map}"
# validate's plots need matplotlib, which the system python3 lacks
ANA_PYTHON=/cvmfs/mu2e.opensciencegrid.org/env/ana/current/bin/python3
MDS_PYTHON="${MDS_PYTHON:-$( [[ -x ${ANA_PYTHON} ]] && echo "${ANA_PYTHON}" || echo python3 )}"
VALIDATION_PY="${ENSEMBLE_DIR}/scripts/plot_ensemble_validation.py"

TAG=""
WORKROOT="${MDS_WORKROOT:-$PWD}"
DRY_RUN=0
FORCE=0
SHIFT=0

# ---------------------------------------------------------------- logging
log()    { echo "$*"; }
ok()     { echo "   ✓ $*"; }
warn()   { echo "   ⚠️  $*" >&2; }
die()    { echo "❌ $*" >&2; exit 1; }
header() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "$*"
  echo "   Tag: ${TAG} | Workdir: ${WORKDIR}$( (( DRY_RUN )) && echo ' | DRY RUN')"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
}

# ---------------------------------------------------------------- options
# Handle the options every step accepts. Sets SHIFT to the number of words
# consumed; returns 1 if $1 is not a common option.
parse_common_opt() {
  case "$1" in
    --tag)      TAG=${2:?--tag needs a value};      SHIFT=2 ;;
    --workroot) WORKROOT=${2:?--workroot needs a value}; SHIFT=2 ;;
    --dry-run)  DRY_RUN=1; SHIFT=1 ;;
    --force)    FORCE=1;   SHIFT=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) return 1 ;;
  esac
}

# Fetch the value of an option that takes an argument, failing cleanly if missing.
optval() { [[ $# -ge 2 && -n $2 ]] || die "$1 needs a value"; echo "$2"; }

# ---------------------------------------------------------------- workdir
# Resolve the tag's working directory, cd into it, take a lock so two steps
# can't run on the same tag at once, and tee all output to run_logs/.
enter_workdir() {
  local step=$1 create=${2:-0}
  [[ -n ${TAG} ]] || die "--tag is required"
  [[ ${TAG} =~ ^[A-Za-z0-9]+$ ]] || die "--tag must be alphanumeric, got '${TAG}'"
  (( create )) && mkdir -p "${WORKROOT}/${TAG}"
  WORKROOT=$(cd "${WORKROOT}" 2>/dev/null && pwd) || die "workroot ${WORKROOT} does not exist"
  WORKDIR="${WORKROOT}/${TAG}"
  MANIFEST="${WORKDIR}/manifest.env"
  if (( ! create )); then
    [[ -f ${MANIFEST} ]] || die "No manifest at ${MANIFEST}; run 'mds.sh init --tag ${TAG}' first (or pass --workroot)"
  fi
  cd "${WORKDIR}"
  mkdir -p run_logs
  exec 9>"${WORKDIR}/.lock"
  flock -n 9 || die "Another mds.sh step is running on ${TAG}"
  local logfile="run_logs/${step}-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "${logfile}") 2>&1
  # init starts a fresh manifest, so it must not pick up old values
  (( create )) || manifest_load
  return 0
}

# ---------------------------------------------------------------- manifest
manifest_load() {
  # shellcheck disable=SC1090
  source "${MANIFEST}"
}

# manifest_set KEY VALUE: replace KEY in place (or append) and set it in this shell.
manifest_set() {
  local key=$1 val=$2 esc tmp
  [[ ${key} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "bad manifest key '${key}'"
  esc=${val//\\/\\\\}; esc=${esc//\"/\\\"}; esc=${esc//\$/\\\$}; esc=${esc//\`/\\\`}
  tmp=$(mktemp "${MANIFEST}.XXXXXX")
  touch "${MANIFEST}"
  LINE="${key}=\"${esc}\"" KEY="${key}" awk '
    index($0, ENVIRON["KEY"] "=") == 1 { print ENVIRON["LINE"]; done = 1; next }
    { print }
    END { if (!done) print ENVIRON["LINE"] }' "${MANIFEST}" > "${tmp}"
  mv "${tmp}" "${MANIFEST}"
  printf -v "${key}" '%s' "${val}"
}

# Append KEY="VALUE" lines (e.g. from yields.py) to the manifest.
manifest_merge() {
  local line key val
  while IFS= read -r line; do
    [[ ${line} =~ ^([A-Za-z_][A-Za-z0-9_]*)=\"(.*)\"$ ]] || die "unexpected line '${line}'"
    key=${BASH_REMATCH[1]}; val=${BASH_REMATCH[2]}
    manifest_set "${key}" "${val}"
  done
}

manifest_require() {
  local k
  for k in "$@"; do
    [[ -n ${!k:-} ]] || die "manifest is missing '${k}' (${MANIFEST})"
  done
}

# ---------------------------------------------------------------- step markers
step_done()    { manifest_set "step_${1}_done" "$(date -Iseconds)"; }
step_is_done() { local v="step_${1}_done"; [[ -n ${!v:-} ]]; }

require_step() {
  local step=$1
  if ! step_is_done "${step}"; then
    (( FORCE )) && { warn "step '${step}' not done; continuing because of --force"; return 0; }
    die "step '${step}' has not been completed; run 'mds.sh ${step} --tag ${TAG}' first (or --force)"
  fi
}

# Exit early if this step already ran, unless --force.
skip_if_done() {
  local step=$1
  if step_is_done "${step}" && (( ! FORCE )); then
    local v="step_${step}_done"
    ok "step '${step}' already done at ${!v}; nothing to do (use --force to redo)"
    exit 0
  fi
}

# ---------------------------------------------------------------- execution
# run CMD...: echo and execute, or only echo under --dry-run. Use it for
# anything that changes state outside the workdir (SAM, tape, poms_map).
run() {
  if (( DRY_RUN )); then
    echo "   [dry-run] $*"
    return 0
  fi
  echo "   \$ $*"
  "$@"
}

require_cmds() {
  local c missing=()
  for c in "$@"; do command -v "${c}" &>/dev/null || missing+=("${c}"); done
  (( ${#missing[@]} == 0 )) || die "not found in PATH: ${missing[*]} (did you set up muse / mu2einit?)"
}

is_number() { [[ $1 =~ ^[0-9]+([.][0-9]*)?([eE][-+]?[0-9]+)?$ ]]; }

# ---------------------------------------------------------------- SAM helpers
# Latest version letters for a definition pattern, e.g.
#   discover_version 'dts.mu2e.DIOtail95.MDC2025%.art'  ->  ax
# Versions are ordered by length then alphabetically, so 'z' < 'aa'.
discover_version() {
  local pattern=$1 defs
  defs=$(samweb list-definitions --defname="${pattern}" 2>/dev/null || true)
  [[ -n ${defs} ]] || return 0
  { grep -oP "${RELEASE}\K[a-z]+" <<<"${defs}" || true; } \
    | sort -u | awk '{ print length($0), $0 }' | sort -k1,1n -k2,2 | tail -1 | cut -d' ' -f2
}

# Total generated events of a dataset (0 if unknown).
dataset_generated() {
  local n
  n=$(samDatasetsSummary.sh "$1" 2>/dev/null | awk '/Generated/ { printf "%.0f", $2 }' || true)
  echo "${n:-0}"
}

# File count of a dataset, or "?" if SAM can't say.
dataset_count() {
  samweb count-files "dh.dataset=$1" 2>/dev/null || echo "?"
}

# Sort a file of paths by basename so the "first N files" are reproducible.
sort_by_basename() {
  awk -F/ '{ print $NF "\t" $0 }' "$1" | sort -t$'\t' -k1,1 | cut -f2-
}

# Shuffle reproducibly when a seed is given.
seeded_shuf() {
  local seed=$1; shift
  if [[ -n ${seed} ]]; then
    shuf --random-source=<(openssl enc -aes-256-ctr -pass pass:"${seed}" -nosalt </dev/zero 2>/dev/null) "$@"
  else
    shuf "$@"
  fi
}

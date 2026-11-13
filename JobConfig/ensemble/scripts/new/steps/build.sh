#!/usr/bin/bash
# Stage 2: find input datasets, build file lists and template FCL, make the
# mu2ejobdef tarball and its index definition.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh build --tag <TAG> [--pin LABEL=VERSION ...] [--dry-run] [--force]
  e.g. mds.sh build --tag MDS4a
       mds.sh build --tag MDS4a --pin DIO=au --pin RPCExternal=av

Input dataset versions are discovered from SAM (latest <release><letters>) unless
pinned. LABEL is one of: DIO RPCInternal RPCExternal IPAMichel
  RMCPhaseSpace0NInternal RMCPhaseSpace0NExternal RMCPhaseSpace1NInternal RMCPhaseSpace1NExternal
Each one is looked up separately (internal/external and 0N/1N no longer share a version).

--dry-run prints the SAM index definition instead of creating it.
EOF
}

declare -A PIN=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pin) p=$(optval "$@"); [[ ${p} == *=* ]] || die "--pin wants LABEL=VERSION, got '${p}'"
           PIN[${p%%=*}]=${p#*=}; shift 2 ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done

enter_workdir build
require_step init
if step_is_done publish && (( ! FORCE )); then
  die "tag ${TAG} is already published (${step_publish_done}); rebuilding would not match the tarball on tape. Use --force if you really mean it."
fi
skip_if_done build
manifest_require release version dsconf simjob_setup run samplingseed njobs CosmicJob BB DEM_emin RPC_TMIN RPC_emin RMC_kmax IPA_emin onspilltime
require_cmds samweb mu2eDatasetFileList samDatasetsSummary.sh mu2ejobdef mu2ejobquery
header "📊 Stage 2 (build): file lists, template FCL and job tarball"
RELEASE=${release}

# label | dataset prefix (version appended) | mu2eDatasetFileList location | expected-yield key
# Order matches Stage2_build_sampler.sh's --sampling order.
PROCESSES=(
  "DIO|dts.mu2e.DIOtail${DEM_emin}|default|dio_events"
  "CRYCosmic|-|-|-"
  "RPCInternal|dts.mu2e.RPCInternalPhysical|--tape|rpc_internal_events"
  "RPCExternal|dts.mu2e.RPCExternalPhysical|default|rpc_external_events"
)
if [[ -n ${RMC_N0_emin:-} ]]; then
  PROCESSES+=("RMCPhaseSpace0NInternal|dts.mu2e.RMCPhaseSpace0NInternal|default|rmc_n0_internal_events")
  PROCESSES+=("RMCPhaseSpace0NExternal|dts.mu2e.RMCPhaseSpace0NExternal|default|rmc_n0_external_events")
fi
if [[ -n ${RMC_N1_emin:-} ]]; then
  PROCESSES+=("RMCPhaseSpace1NInternal|dts.mu2e.RMCPhaseSpace1NInternal|default|rmc_n1_internal_events")
  PROCESSES+=("RMCPhaseSpace1NExternal|dts.mu2e.RMCPhaseSpace1NExternal|default|rmc_n1_external_events")
fi
PROCESSES+=("IPAMichel|dts.mu2e.IPAMuminusMichel|--tape|ipa_events")
LABELS=()
for row in "${PROCESSES[@]}"; do LABELS+=("${row%%|*}"); done
for l in "${!PIN[@]}"; do
  [[ " ${LABELS[*]} " == *" ${l} "* && ${l} != CRYCosmic ]] || die "--pin: unknown label '${l}'"
done

# ---------------------------------------------------------------- versions
log "🔍 [1/6] Input dataset versions..."
for row in "${PROCESSES[@]}"; do
  IFS='|' read -r label prefix _ _ <<<"${row}"
  [[ ${label} == CRYCosmic ]] && continue
  if [[ -n ${PIN[${label}]:-} ]]; then
    v=${PIN[${label}]}; how="pinned"
  else
    v=$(discover_version "${prefix}.${RELEASE}%.art"); how="latest in SAM"
    [[ -n ${v} ]] || die "no SAM definition matches ${prefix}.${RELEASE}%.art; pin it with --pin ${label}=<letters>"
  fi
  manifest_set "input_ds_${label}" "${prefix}.${RELEASE}${v}.art"
  ok "$(printf '%-24s %s (%s)' "${label}" "${prefix}.${RELEASE}${v}.art" "${how}")"
done
manifest_set input_ds_CRYCosmic "dts.mu2e.CosmicSignal.${CosmicJob}.art"
log ""

# ---------------------------------------------------------------- availability
log "🔍 [2/6] Checking files and generated events (need ${njobs} files each)..."
FAILED=0
for row in "${PROCESSES[@]}"; do
  IFS='|' read -r label _ loc yield_key <<<"${row}"
  ds_key="input_ds_${label}"; ds=${!ds_key}
  if [[ ${label} == CRYCosmic ]]; then
    # chosen in init, so the livetime matches these exact files
    [[ -s lists/CRYCosmic.chosen ]] || die "lists/CRYCosmic.chosen missing; rerun init"
    cp lists/CRYCosmic.chosen lists/CRYCosmic.sorted.chosen
    ok "$(printf '%-24s %s files (chosen in init)' "${label}" "$(wc -l < lists/CRYCosmic.chosen)")"
    continue
  fi
  if [[ ${loc} == default ]]; then
    mu2eDatasetFileList "${ds}" > "lists/${label}.all" || true
  else
    mu2eDatasetFileList "${ds}" "${loc}" > "lists/${label}.all" || true
  fi
  sort_by_basename "lists/${label}.all" > "lists/${label}.sorted"
  nfiles=$(wc -l < "lists/${label}.sorted")
  if (( nfiles < njobs )); then
    echo "   ❌ ${label}: only ${nfiles} files available (${loc}), need ${njobs}"
    FAILED=1; continue
  fi
  head -n "${njobs}" "lists/${label}.sorted" > "lists/${label}.sorted.chosen"
  gen=$(dataset_generated "${ds}")
  need=$(printf '%.0f' "${!yield_key:-0}")
  if (( gen == 0 )); then
    echo "   ❌ ${label}: could not get generated events for ${ds}"
    FAILED=1; continue
  fi
  if (( need == 0 )); then
    echo "   ❌ ${label}: no expected yield '${yield_key}' in the manifest"
    FAILED=1; continue
  fi
  if (( gen < need )); then
    echo "   ❌ ${label}: ${gen} generated events in the dataset, ${need} needed (short by $((need - gen)))"
    FAILED=1; continue
  fi
  # the job only sees njobs of nfiles files; estimate what those carry
  in_chosen=$(( gen * njobs / nfiles ))
  ok "$(printf '%-24s %s files, %s generated, %s expected' "${label}" "${nfiles}" "${gen}" "${need}")"
  (( in_chosen >= need )) || warn "${label}: the ${njobs} chosen files hold ~${in_chosen} generated events, fewer than ${need} expected"
done
(( FAILED == 0 )) || die "one or more inputs are short of files or events"
log ""

# ---------------------------------------------------------------- file lists
log "🔨 [3/6] Writing file lists..."
for label in "${LABELS[@]}"; do
  cp "lists/${label}.sorted.chosen" "filenames_${label}"            # paths, read by make_template_fcl.py
  awk -F/ '{ print $NF }' "filenames_${label}" > "filenames_${label}_${njobs}.txt"   # SAM names, for mu2ejobdef
  [[ -s filenames_${label}_${njobs}.txt ]] || die "empty file list for ${label}"
done
ok "filenames_<label> and filenames_<label>_${njobs}.txt hold the same ${njobs} files per process"
log ""

# ---------------------------------------------------------------- template FCL
log "📝 [4/6] Generating template FCL (make_template_fcl.py)..."
rm -f SamplingInput_sr*.fcl
# unbuffered, so its progress shows up through the tee to run_logs/
PYTHONUNBUFFERED=1 "${ENSEMBLE_PY}/make_template_fcl.py" --BB="${BB}" --release="${RELEASE}${version}" --tag="${TAG}" \
  --verbose=1 --livetime="${onspilltime}" --run="${run}" --dioemin="${DEM_emin}" --rpcemin="${RPC_emin}" \
  --rmcn0emin="${RMC_N0_emin:-}" --rmcn1emin="${RMC_N1_emin:-}" --rmckmax="${RMC_kmax}" \
  --ipaemin="${IPA_emin}" --tmin="${RPC_TMIN}" --samplingseed="${samplingseed}" --prc "${LABELS[@]}" \
  | tee make_template.out
[[ -f SamplingInput_sr0.fcl ]] || die "make_template_fcl.py did not write SamplingInput_sr0.fcl"
ok "template FCL written"
# expected dts yields (generated-level yield x dts efficiency) and the sampled
# target, which validate compares the ensemble against
while read -r label n; do
  manifest_set "dts_expected_${label}" "${n}"
done < <(awk '/^[A-Za-z0-9]+$/ { label = $0 }
              /^NORM / && /EXPECTED EVENTS:/ && label != "" { print label, $NF; label = "" }' make_template.out)
target=$(awk '/^TOTAL EXPECTED EVENTS:/ && /GENERATING:/ { print $NF }' make_template.out)
[[ -n ${target} ]] || die "no TOTAL EXPECTED EVENTS line in make_template.out"
manifest_set sample_target "${target}"
ok "expected dts yields and the sampled target (${target}) recorded"
log ""

# ---------------------------------------------------------------- tarball
log "🏗️  [5/6] Building the job tarball (mu2ejobdef)..."
rm -f cnf.*.ensemble."${dsconf}".0.tar
SAMPLING_OPTS=()
for label in "${LABELS[@]}"; do SAMPLING_OPTS+=("--sampling=1:${label}:filenames_${label}_${njobs}.txt"); done
echo "   \$ mu2ejobdef --desc=ensemble --dsconf=${dsconf} --run=${run} --setup ${simjob_setup} ${SAMPLING_OPTS[*]} --embed SamplingInput_sr0.fcl --verb"
mu2ejobdef --desc=ensemble --dsconf="${dsconf}" --run="${run}" --setup "${simjob_setup}" \
  "${SAMPLING_OPTS[@]}" --embed SamplingInput_sr0.fcl --verb
shopt -s nullglob
tars=(cnf.*.ensemble."${dsconf}".0.tar)
shopt -u nullglob
(( ${#tars[@]} == 1 )) || die "expected one cnf.*.ensemble.${dsconf}.0.tar, found ${#tars[@]}"
TARBALL=${tars[0]}
JOBS=$(mu2ejobquery --njobs "${TARBALL}")
ok "${TARBALL}: ${JOBS} jobs"
(( JOBS == njobs )) || warn "the tarball defines ${JOBS} jobs but njobs is ${njobs}"
log ""

# ---------------------------------------------------------------- index definition
log "🗂️  [6/6] Index definition..."
index_dataset=${TARBALL#cnf.}; index_dataset=${index_dataset%.0.tar}
IDX_DEF="idx_${index_dataset}"
if samweb describe-definition "${IDX_DEF}" &>/dev/null; then
  ok "${IDX_DEF} already exists; leaving it alone"
else
  run samweb create-definition "${IDX_DEF}" "dh.dataset etc.mu2e.index.000.txt and dh.sequencer < $(printf '%07d' "${JOBS}")"
fi

if (( DRY_RUN )); then
  log ""; log "Dry run: build not marked done."; exit 0
fi
manifest_set tarball      "${TARBALL}"
manifest_set jobdef_njobs "${JOBS}"
manifest_set index_def    "${IDX_DEF}"
step_done build

log ""
log "═══════════════════════════════════════════════════════════════"
log "✅ build complete: ${TARBALL} (${JOBS} jobs), ${IDX_DEF}"
log "   Next: mds.sh publish --tag ${TAG} --workroot ${WORKROOT} --dry-run   (then without --dry-run)"
log "═══════════════════════════════════════════════════════════════"

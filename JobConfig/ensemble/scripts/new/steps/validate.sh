#!/usr/bin/bash
# Stage 4: check the ensemble job logs against the weights in the template FCL
# and the expected dts yields from build, using
# ../scripts/plot_ensemble_validation.py.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh validate --tag <TAG> [--logs DIR] [--nsigma 5] [--no-plots] [--accept]

Reads the ensemble job logs in place from the log dataset on pnfs,
  \${MDS_LOG_ROOT:-/pnfs/mu2e/persistent/datasets/phy-etc/log}/<owner>/ensemble/<dsconf>/log
e.g. .../log/mu2e/ensemble/MDC2025ax_MDS4a/log; --logs DIR reads another directory.

Each log's SamplingInput table gives, per process, the sampled count and the
input that ran out and ended the job. Validation fails when
  - a process's fraction over all jobs is more than --nsigma from its weight
  - logs have no table, or there are fewer jobs than the tarball defines
  - a process is more than --nsigma Poisson sigmas from its expected dts yield
    (generated-level yield x dts efficiency, recorded by build), or the total
    is more than --nsigma from the sampled target
--accept records the step as done anyway.

Writes <workdir>/validate.txt (the report), validate.csv (per job, per process)
and validate.pdf (plots; --no-plots skips them). Then runs
../ensemble_livetime.py for the livetime that was actually built, requested x
(events built / target), into livetime.txt, and records it in the manifest as
true_onspilltime, true_beam_livetime and true_beam_npot (with samweb, events
built is the dts dataset's count in SAM; otherwise the sum of the logs). The plots need matplotlib:
\$MDS_PYTHON, default ${MDS_PYTHON}.
EOF
}

LOGDIR=""; NSIGMA=5; ACCEPT=0; PLOTS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --logs)     LOGDIR=$(optval "$@"); shift 2 ;;
    --nsigma)   NSIGMA=$(optval "$@"); shift 2 ;;
    --no-plots) PLOTS=0; shift ;;
    --accept)   ACCEPT=1; shift ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done
[[ -z ${LOGDIR} || ${LOGDIR} == /* ]] || LOGDIR="${PWD}/${LOGDIR}"

enter_workdir validate
require_step publish
header "🔍 Stage 4 (validate): sampled events vs weights and expected dts yields"
manifest_require owner dsconf
LOGDIR=${LOGDIR:-${MDS_LOG_ROOT:-/pnfs/mu2e/persistent/datasets/phy-etc/log}/${owner}/ensemble/${dsconf}/log}
[[ -d ${LOGDIR} ]] || die "no log directory ${LOGDIR}; has the ensemble campaign finished? (or pass --logs)"
[[ -f ${VALIDATION_PY} ]] || die "missing ${VALIDATION_PY}"

ARGS=(--logs "${LOGDIR}" --out validate --check --nsigma "${NSIGMA}")
[[ -n ${jobdef_njobs:-} ]] && ARGS+=(--njobs "${jobdef_njobs}")
[[ -f SamplingInput_sr0.fcl ]] && ARGS+=(--fcl SamplingInput_sr0.fcl)
(( PLOTS )) || ARGS+=(--no-plots)

# expected dts yields: from the manifest, or (for a tag built before build
# recorded them) from the make_template_fcl.py output in the build logs
mapfile -t EXP_KEYS < <(compgen -v dts_expected_ || true)
if (( ${#EXP_KEYS[@]} > 0 )); then
  for k in "${EXP_KEYS[@]}"; do ARGS+=(--expected "${k#dts_expected_}=${!k}"); done
  [[ -n ${sample_target:-} ]] && ARGS+=(--target "${sample_target}")
  log "Expected dts yields: ${#EXP_KEYS[@]} processes from the manifest, target ${sample_target:-?}"
else
  stage2=$(grep -l "EXPECTED EVENTS:" make_template.out run_logs/build-*.log 2>/dev/null | tail -1 || true)
  if [[ -n ${stage2} ]]; then
    ARGS+=(--stage2-log "${stage2}")
    log "Expected dts yields: from ${stage2}"
  else
    warn "no expected dts yields (rerun build, or check by hand); only the weights are checked"
  fi
fi
log ""

REPORT="validate.txt"
log "\$ ${MDS_PYTHON} ${VALIDATION_PY} ${ARGS[*]}"
set +e
"${MDS_PYTHON}" "${VALIDATION_PY}" "${ARGS[@]}" 2>&1 | tee "${REPORT}"
rc=${PIPESTATUS[0]}
set -e
grep -q "^VALIDATION: " "${REPORT}" || die "the validation script did not finish (exit ${rc}); see ${WORKDIR}/${REPORT}"
grep -q "^VALIDATION: FAIL" "${REPORT}" && FAILED=1 || FAILED=0
(( FAILED || rc == 0 )) || die "the validation script failed (exit ${rc}) after its checks; see ${WORKDIR}/${REPORT}"
log ""
log "   dts output in SAM: $(dataset_count "${ds_dts}") files of ${jobdef_njobs:-?} jobs (${ds_dts})"
log ""

if (( FAILED )) && (( ! ACCEPT )); then
  die "validation failed (report: ${WORKDIR}/${REPORT}); investigate, or rerun with --accept"
fi
manifest_set validate_logs "$(sed -n 's/^jobs with a table: \([0-9]*\).*/\1/p' "${REPORT}")"

# the livetime that was built (requested x events built / target), from the
# per-job table just written and, where samweb is available, the dts count in SAM
LIVETIME_PY="${ENSEMBLE_DIR}/scripts/ensemble_livetime.py"
LT_ARGS=(--from-csv validate.csv --manifest "${MANIFEST}" --env)
command -v samweb >/dev/null && LT_ARGS+=(--sam)
log "\$ ${MDS_PYTHON} ${LIVETIME_PY} ${LT_ARGS[*]}"
if "${MDS_PYTHON}" "${LIVETIME_PY}" "${LT_ARGS[@]}" > livetime.txt; then
  sed '/^true_[a-z_]*="/d' livetime.txt
  manifest_merge < <(grep '^true_[a-z_]*="' livetime.txt)
  ok "true on-spill livetime ${true_onspilltime} s of ${onspilltime} s requested (livetime.txt)"
else
  warn "could not compute the true livetime; see ${WORKDIR}/livetime.txt"
fi
log ""
step_done validate
log "═══════════════════════════════════════════════════════════════"
log "✅ validate complete$( (( FAILED )) && echo ' (accepted with failures)'). Report: ${WORKDIR}/${REPORT}"
(( PLOTS )) && log "   Plots: ${WORKDIR}/validate.pdf"
log "   Next: mds.sh digireco --tag ${TAG} --workroot ${WORKROOT}"
log "═══════════════════════════════════════════════════════════════"

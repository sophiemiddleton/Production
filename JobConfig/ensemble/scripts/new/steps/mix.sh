#!/usr/bin/bash
# Stage 6: hadd each pseudo-experiment's shuffled signal + known-physics list
# into the final ntuples.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh mix --tag <TAG> [--label NAME] [--pe N|all] [--files-per-merge 2] [--force]

Merges signal/<label>/pe_<N>/mixed_files.txt in groups of --files-per-merge into
signal/<label>/pe_<N>/merged/, listing the outputs in pe_<N>/merged_list.txt.
--label can be omitted when there is only one signal set.
EOF
}

LABEL=""; PE="all"; PER_MERGE=2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)           LABEL=$(optval "$@"); shift 2 ;;
    --pe)              PE=$(optval "$@"); shift 2 ;;
    --files-per-merge) PER_MERGE=$(optval "$@"); shift 2 ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done
[[ ${PER_MERGE} =~ ^[1-9][0-9]*$ ]] || die "--files-per-merge must be a positive integer"

enter_workdir mix
require_cmds hadd
manifest_require BB
if [[ -z ${LABEL} ]]; then
  shopt -s nullglob; sets=(signal/*/signal.env); shopt -u nullglob
  (( ${#sets[@]} == 1 )) || die "found ${#sets[@]} signal sets; pick one with --label"
  LABEL=$(basename "$(dirname "${sets[0]}")")
fi
OUT="${WORKDIR}/signal/${LABEL}"
[[ -f ${OUT}/signal.env ]] || die "no completed signal set at ${OUT}; run 'mds.sh signal' first"
# shellcheck disable=SC1091
source "${OUT}/signal.env"
header "🔀 Stage 6 (mix): ${signal} at Rmue=${Rmue}, livetime ${livetime_combined} s (signal/${LABEL})"

if [[ ${PE} == all ]]; then
  PES=$(seq 1 "${npseudo_experiments}")
else
  [[ ${PE} =~ ^[1-9][0-9]*$ && ${PE} -le ${npseudo_experiments} ]] || die "--pe must be 1..${npseudo_experiments} or all"
  PES=${PE}
fi

for i in ${PES}; do
  pe="${OUT}/pe_${i}"
  list="${pe}/mixed_files.txt"
  merged="${pe}/merged"
  [[ -s ${list} ]] || die "missing or empty ${list}"
  if [[ -s ${pe}/merged_list.txt ]] && (( ! FORCE )); then
    ok "pe_${i} already merged ($(wc -l < "${pe}/merged_list.txt") files); --force to redo"
    continue
  fi
  rm -rf "${merged}"; mkdir -p "${merged}"
  : > "${pe}/merged_list.txt"
  outname="nts.mu2e.ensemble${TAG}Mix${BB}_${signal}_${Rmue}_${livetime_combined}.${i}"
  log "  [pe_${i}] merging $(wc -l < "${list}") files, ${PER_MERGE} at a time..."
  mapfile -t files < "${list}"
  group=0
  for (( start = 0; start < ${#files[@]}; start += PER_MERGE )); do
    group=$(( group + 1 ))
    out="${merged}/${outname}_${group}.root"
    hadd -f -k "${out}" "${files[@]:start:PER_MERGE}" > "${merged}/hadd_${group}.log" 2>&1 \
      || die "hadd failed for group ${group}; see ${merged}/hadd_${group}.log"
    echo "${out}" >> "${pe}/merged_list.txt"
  done
  ok "pe_${i}: ${group} merged files listed in ${pe}/merged_list.txt"
done

log ""
log "═══════════════════════════════════════════════════════════════"
log "✅ mix complete: ${OUT}/pe_*/merged_list.txt"
log "═══════════════════════════════════════════════════════════════"

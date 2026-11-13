#!/usr/bin/bash
# Show where a tag is: configuration, finished steps, SAM file counts, next command.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh status --tag <TAG> [--no-sam]
  --no-sam   skip the SAM file counts (they need samweb and a few seconds)
EOF
}

SAM=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-sam) SAM=0; shift ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done

enter_workdir status
header "📋 Status of ${TAG}"

log "Configuration"
log "   ${release}${version} | ${type:-?} | ${BB} | njobs ${njobs} | cosmics ${CosmicJob}"
log "   livetime ${onspilltime} s on-spill, ${beam_livetime} s total | POT ${beam_pot:-?}"
[[ -n ${true_onspilltime:-} ]] && log "   built    ${true_onspilltime} s on-spill, ${true_beam_livetime:-?} s total | POT ${true_beam_npot:-?} (${true_fraction} of requested)"
log "   DIO ${dio_events} | IPA ${ipa_events} | RPC int ${rpc_internal_events} ext ${rpc_external_events}"
[[ -n ${RMC_N0_emin:-} ]] && log "   RMC 0N int ${rmc_n0_internal_events} ext ${rmc_n0_external_events}"
[[ -n ${RMC_N1_emin:-} ]] && log "   RMC 1N int ${rmc_n1_internal_events} ext ${rmc_n1_external_events}"
log ""

log "Steps"
NEXT=""
for s in init build publish validate digireco; do
  v="step_${s}_done"
  if [[ -n ${!v:-} ]]; then
    ok "$(printf '%-9s %s' "${s}" "${!v}")"
  else
    echo "   ·  ${s}"
    [[ -z ${NEXT} ]] && NEXT=${s}
  fi
done
shopt -s nullglob
for f in signal/*/signal.env; do
  d=$(dirname "${f}"); merged=("${d}"/pe_*/merged_list.txt); n=${#merged[@]}
  ok "$(printf '%-9s %s (%s of %s pe merged)' signal "${d#signal/}" "${n}" "$(sed -n 's/^npseudo_experiments="\(.*\)"/\1/p' "${f}")")"
done
shopt -u nullglob
log ""

if (( SAM )); then
  require_cmds samweb
  log "SAM datasets (files)"
  for k in ds_dts ds_dig ds_mcs ds_nts; do
    printf '   %-6s %6s  %s\n' "${k#ds_}" "$(dataset_count "${!k}")" "${!k}"
  done
  log "   (the ensemble tarball defines ${jobdef_njobs:-?} jobs)"
  log ""
fi

case "${NEXT}" in
  "")       log "Next: mds.sh signal --tag ${TAG} --workroot ${WORKROOT} --signal <name>" ;;
  validate) log "Next: once the ensemble campaign is done, run mds.sh validate --tag ${TAG} --workroot ${WORKROOT}" ;;
  *)        log "Next: mds.sh ${NEXT} --tag ${TAG} --workroot ${WORKROOT}" ;;
esac

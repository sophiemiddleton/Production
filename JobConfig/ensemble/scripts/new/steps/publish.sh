#!/usr/bin/bash
# Stage 3: declare and upload the job tarball and the tag-info file, write the
# ensemble campaign JSON and install it in poms_map.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh publish --tag <TAG> [--dry-run] [--force]

Declares to SAM, uploads, and copies into ${POMS_MAP}. Each action first
checks whether it was already done (file declared? location registered? same
JSON already in poms_map?), so a rerun after a failure picks up where it stopped.
Run with --dry-run first to see exactly what would happen.
--force overwrites a different ${RELEASE:-<release>}-<TAG>.json already in poms_map.
EOF
}

while [[ $# -gt 0 ]]; do
  parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT}
done

enter_workdir publish
require_step build
skip_if_done publish
manifest_require release version owner tarball njobs
require_cmds samweb printJson mu2eFileDeclare mu2eFileUpload
header "📤 Stage 3 (publish): SAM, tape and POMS campaign"
RELEASE=${release}
[[ -f ${tarball} ]] || die "tarball ${tarball} not found in ${WORKDIR}"

declare_json() { printf '%s\n' "$1" | mu2eFileDeclare; }

# Declare FILE (via FILE.json), upload it and register its location.
# Skips whatever SAM says is already done.
publish_file() {
  local file=$1 json="$1.json" out tape_file
  if samweb get-metadata "${file}" &>/dev/null; then
    ok "${file} already declared"
  else
    printJson --no-parents "${file}" > "${json}"
    [[ -s ${json} ]] || die "printJson produced nothing for ${file}"
    run declare_json "${json}"
    (( DRY_RUN )) || ok "${file} declared"
  fi

  if [[ -n $(samweb locate-file "${file}" 2>/dev/null || true) ]]; then
    ok "${file} already has a location: $(samweb locate-file "${file}" | head -1)"
    return 0
  fi
  if (( DRY_RUN )); then
    echo "   [dry-run] printf '%s\\n' ${file} | mu2eFileUpload --disk"
    echo "   [dry-run] samweb add-file-location ${file} enstore:<directory from upload output>"
    return 0
  fi
  echo "   \$ printf '%s\\n' ${file} | mu2eFileUpload --disk"
  out=$(printf '%s\n' "${file}" | mu2eFileUpload --disk 2>&1) || { echo "${out}"; die "upload of ${file} failed"; }
  echo "${out}"
  tape_file=$(sed -n 's/.*to \(\/pnfs[^ ]*\).*/\1/p' <<<"${out}" | head -1)
  [[ -n ${tape_file} ]] || die "could not find the /pnfs path in the upload output above"
  run samweb add-file-location "${file}" "enstore:$(dirname "${tape_file}")"
  ok "${file} -> $(dirname "${tape_file}")"
}

# ---------------------------------------------------------------- tarball
log "📦 [1/3] Job tarball ${tarball}"
publish_file "${tarball}"
log ""

# ---------------------------------------------------------------- tag info
TAG_INFO="cnf.${owner}.${TAG}-info.${RELEASE}${version}.0.txt"
log "📋 [2/3] Tag-info file ${TAG_INFO}"
if ! samweb get-metadata "${TAG_INFO}" &>/dev/null; then
  # the manifest without the workflow bookkeeping
  grep -v '^step_' "${MANIFEST}" > "${TAG_INFO}"
fi
publish_file "${TAG_INFO}"
log ""

# ---------------------------------------------------------------- campaign JSON
CAMPAIGN_JSON="${RELEASE}-${TAG}.json"
log "📋 [3/3] Campaign JSON ${CAMPAIGN_JSON}"
cat > "${CAMPAIGN_JSON}" <<EOF
[
{
    "tarball": "${tarball}",
    "njobs": ${njobs},
    "inloc": "disk",
    "outputs": [
      {
        "dataset": "*.art",
        "location": "tape"
      }
    ]
  }
]
EOF
ok "wrote ${WORKDIR}/${CAMPAIGN_JSON}"
dest="${POMS_MAP}/${CAMPAIGN_JSON}"
if [[ -f ${dest} ]] && cmp -s "${CAMPAIGN_JSON}" "${dest}"; then
  ok "${dest} is already identical"
elif [[ -f ${dest} ]] && (( ! FORCE )); then
  diff "${dest}" "${CAMPAIGN_JSON}" || true
  die "${dest} exists and differs (above); rerun with --force to overwrite it"
else
  run cp "${CAMPAIGN_JSON}" "${dest}"
fi

if (( DRY_RUN )); then
  log ""; log "Dry run: nothing declared, uploaded or copied; publish not marked done."; exit 0
fi
manifest_set tag_info      "${TAG_INFO}"
manifest_set campaign_json "${dest}"
step_done publish

log ""
log "═══════════════════════════════════════════════════════════════"
log "✅ publish complete"
log "   Run the ensemble campaign (as mu2epro):"
log "     1) set up a POMS campaign in the GUI"
log "     2) mkidxdef --jobdefs ${dest} --prod"
log "     3) launch it from the GUI"
log "   When it finishes: mds.sh status --tag ${TAG} --workroot ${WORKROOT}"
log "   then run mds.sh validate --tag ${TAG} --workroot ${WORKROOT}"
log "═══════════════════════════════════════════════════════════════"

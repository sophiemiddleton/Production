#!/usr/bin/bash
# Stage 3 --append: write the digi / reco / ntuple stage JSON for the ensemble
# and print the json2jobdef commands that turn it into POMS job definitions.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

usage() { cat <<EOF
Usage: mds.sh digireco --tag <TAG> [--digi-merge 100] [--install] [--jobdefs PATH] [--dry-run]

Writes <workdir>/<release>-<TAG>-stages.json (digi -> reco -> ntuple), taking
dataset names, DB purpose/version and Musings versions from the manifest.

  --digi-merge N  dts files per digi job, the value in "input_data" [100, which
                  is what Stage3 --append always ended up using]
  --install       also copy the stages JSON into ${POMS_MAP} under its own
                  name; unlike Stage3 --append it never overwrites <release>-<TAG>.json
  --jobdefs PATH  jobdefs file passed to json2jobdef in the printed commands
                  [${POMS_MAP}/<release>-<TAG>.json]
EOF
}

DIGI_MERGE=100; INSTALL=0; JOBDEFS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --digi-merge) DIGI_MERGE=$(optval "$@"); shift 2 ;;
    --install)    INSTALL=1; shift ;;
    --jobdefs)    JOBDEFS=$(optval "$@"); shift 2 ;;
    *) parse_common_opt "$@" || { usage; die "unknown option '$1'"; }; shift ${SHIFT} ;;
  esac
done
[[ ${DIGI_MERGE} =~ ^[0-9]+$ ]] || die "--digi-merge must be an integer"

enter_workdir digireco
require_step validate
manifest_require release version dbpurpose dbversion anaversion dsconf_digi ntuple_dsconf ds_dts ds_dig ds_mcs
header "📋 Stage 3b (digireco): digi / reco / ntuple stages"
RELEASE=${release}
SIMJOB="/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${RELEASE}${version}/setup.sh"
ANAJOB="/cvmfs/mu2e.opensciencegrid.org/Musings/Analysis${RELEASE}/${anaversion}/setup.sh"
STAGES_JSON="${RELEASE}-${TAG}-stages.json"
JOBDEFS=${JOBDEFS:-${POMS_MAP}/${RELEASE}-${TAG}.json}

[[ -d ${ANAJOB%/setup.sh} ]] || warn "${ANAJOB} not found on cvmfs from here"

cat > "${STAGES_JSON}" <<EOF
[
  {
    "desc": "ensembleOnSpill",
    "dsconf": "${dsconf_digi}",
    "fcl": "Production/JobConfig/digitize/OnSpill.fcl",
    "input_data": {
      "${ds_dts}": ${DIGI_MERGE}
    },
    "fcl_overrides": {
      "services.DbService.purpose": "${dbpurpose}",
      "services.DbService.version": "${dbversion}",
      "outputs.Output.fileName": "dig.owner.{desc}.version.sequencer.art"
    },
    "inloc": "tape",
    "outloc": {"*.art": "tape"},
    "simjob_setup": "${SIMJOB}"
  },
  {
    "desc": "ensembleOnSpillReco",
    "dsconf": "${dsconf_digi}",
    "fcl": "Production/JobConfig/recoMC/OnSpill.fcl",
    "input_data": {
      "${ds_dig}": 1
    },
    "fcl_overrides": {
      "services.DbService.purpose": "${dbpurpose}",
      "services.DbService.version": "${dbversion}",
      "outputs.LoopHelixOutput.fileName": "mcs.owner.{desc}.version.sequencer.art"
    },
    "inloc": "tape",
    "outloc": {"*.art": "tape"},
    "simjob_setup": "${SIMJOB}"
  },
  {
    "desc": "ensembleNtuple",
    "dsconf": ["${ntuple_dsconf}"],
    "fcl": ["EventNtuple/fcl/from_mcs-mockdata.fcl"],
    "input_data": {
      "${ds_mcs}": 1
    },
    "fcl_overrides": {
      "services.TFileService.fileName": "nts.mu2e.{desc}.version.sequencer.root"
    },
    "inloc": "tape",
    "outloc": {"*.root": "disk"},
    "simjob_setup": "${ANAJOB}"
  }
]
EOF
python3 -m json.tool "${STAGES_JSON}" >/dev/null || die "${STAGES_JSON} is not valid JSON"
ok "wrote ${WORKDIR}/${STAGES_JSON}"
JSON_FOR_CMDS="${WORKDIR}/${STAGES_JSON}"

if (( INSTALL )); then
  dest="${POMS_MAP}/${STAGES_JSON}"
  if [[ -f ${dest} ]] && cmp -s "${STAGES_JSON}" "${dest}"; then
    ok "${dest} is already identical"
  elif [[ -f ${dest} ]] && (( ! FORCE )); then
    diff "${dest}" "${STAGES_JSON}" || true
    die "${dest} exists and differs (above); rerun with --force to overwrite it"
  else
    run cp "${STAGES_JSON}" "${dest}"
  fi
  JSON_FOR_CMDS=${dest}
fi

if (( DRY_RUN )); then
  log ""; log "Dry run: digireco not marked done."; exit 0
fi
manifest_set stages_json  "${JSON_FOR_CMDS}"
manifest_set digi_merge   "${DIGI_MERGE}"
step_done digireco

log ""
log "═══════════════════════════════════════════════════════════════"
log "✅ digireco complete. As mu2epro, add the stages to the campaign:"
log "     json2jobdef --json ${JSON_FOR_CMDS} --dsconf ${dsconf_digi} --desc ensembleOnSpill --jobdefs ${JOBDEFS} --prod"
log "     json2jobdef --json ${JSON_FOR_CMDS} --dsconf ${dsconf_digi} --desc ensembleOnSpillReco --jobdefs ${JOBDEFS} --prod"
log "     json2jobdef --json ${JSON_FOR_CMDS} --dsconf ${ntuple_dsconf} --desc ensembleNtuple --jobdefs ${JOBDEFS} --prod"
log "   then relaunch the campaign from the GUI."
log "   Outputs to watch (mds.sh status): ${ds_dig}, ${ds_mcs}, ${ds_nts}"
log "   Afterwards: mds.sh signal --tag ${TAG} --workroot ${WORKROOT} --signal <name>"
log "═══════════════════════════════════════════════════════════════"

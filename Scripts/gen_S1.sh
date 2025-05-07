#!/usr/bin/env bash

# Generate S1 job definitions for Mu2e from a JSON array
# Usage:
#   bash Scripts/gen_S1.sh --json data/stage1_cosmic.json --desc ExtractedCRY [--pushout]

# Defaults
OWNER="mu2e"
JSON_FILE=""
JOB_DESC=""
PUSHOUT=false

# Function: Usage message
usage() {
  cat <<EOF
Usage: $0 [options]

  --owner          NAME   Data owner (default: mu2e)
  --json           FILE   JSON file with an array of job definitions (required)
  --desc           NAME   Job description to select entry from JSON (required)
  --pushout              Enable pushOutput of results (default: disabled)
  --help                  Print this message
EOF
}

# Parse command-line
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)        OWNER="$2";    shift 2;;
    --json)         JSON_FILE="$2";shift 2;;
    --desc)         JOB_DESC="$2"; shift 2;;
    --pushout)      PUSHOUT=true;   shift;;
    --help)         usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# Clean old output
rm -f cnf.*.tar

# Guard: ensure unique desc entries
count=$(jq --arg d "$JOB_DESC" 'map(select(.desc == $d)) | length' "$JSON_FILE")
if (( count != 1 )); then
  echo "Error: found $count entries with desc=\"$JOB_DESC\"; needs to be unique." >&2
  exit 1
fi

# Extract parameters by matching desc
DSCONF=$(jq -r --arg d "$JOB_DESC" 'map(select(.desc == $d))[0].dsconf'        "$JSON_FILE")
DESC=$(jq -r --arg d "$JOB_DESC" 'map(select(.desc == $d))[0].desc'            "$JSON_FILE")
FCL=$(jq -r --arg d "$JOB_DESC" 'map(select(.desc == $d))[0].fcl'              "$JSON_FILE")
EVENTS=$(jq -r --arg d "$JOB_DESC" 'map(select(.desc == $d))[0].events'         "$JSON_FILE")
RUN=$(jq -r --arg d "$JOB_DESC" 'map(select(.desc == $d))[0].run'               "$JSON_FILE")
SIMJOB_SETUP=$(jq -r --arg d "$JOB_DESC" 'map(select(.desc == $d))[0].simjob_setup'  "$JSON_FILE")

# Build and echo mu2ejobdef command as an array
CMD=(
  mu2ejobdef
  --verbose
  --setup "$SIMJOB_SETUP"
  --dsconf "$DSCONF"
  --dsowner "$OWNER"
  --run-number "$RUN"
  --events-per-job "$EVENTS"
  --embed "$FCL"
  --description "$DESC"
)

echo "${CMD[@]}"

# Execute mu2ejobdef
"${CMD[@]}"

# Post-processing: generate test FCL and outputs
echo "Generating job FCL and outputs"
parfile="cnf.${OWNER}.${DESC}.${DSCONF}.0.tar"
test_fcl="${parfile%.tar}.fcl"
mu2ejobfcl --jobdef "$parfile" --index 0 --default-proto root --default-loc tape > "$test_fcl"
cat "$test_fcl"
echo "disk $parfile none" > outputs.txt

# PushOutput logic
if [[ "$PUSHOUT" != true ]]; then
  echo "PushOutput disabled."
elif samweb locate-file "$parfile" &>/dev/null; then
  echo "Exists on SAM; not pushing."
else
  pushOutput outputs.txt
fi

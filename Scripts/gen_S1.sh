#!/usr/bin/env bash

# Generate S1 job definitions for Mu2e from a JSON array
# Usage:
#   bash Scripts/gen_S1.sh --json data/stage1_cosmic.json --json_index 1 [--pushout]

# Defaults
OWNER="mu2e"
JSON_FILE=""
JSON_INDEX=""
PUSHOUT=false

# Function: Usage message
usage() {
  cat <<EOF
Usage: $0 [options]

  --owner          NAME   Data owner (default: mu2e)
  --json           FILE   JSON file with an array of job definitions (required)
  --json_index     INT    Zero-based index into JSON array (required)
  --pushout              Enable pushOutput of results (default: disabled)
  --help                  Print this message
EOF
}

# Parse command-line
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)        OWNER="$2";        shift 2;;
    --json)         JSON_FILE="$2";    shift 2;;
    --json_index)   JSON_INDEX="$2";   shift 2;;
    --pushout)      PUSHOUT=true;       shift;;
    --help)         usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# Clean old output
rm -f cnf.*.tar

# Extract parameters
DSCONF=$(jq -r ".[$JSON_INDEX].dsconf" "$JSON_FILE")
DESC=$(jq -r ".[$JSON_INDEX].desc" "$JSON_FILE")
FCL=$(jq -r ".[$JSON_INDEX].fcl" "$JSON_FILE")
EVENTS=$(jq -r ".[$JSON_INDEX].events" "$JSON_FILE")
RUN=$(jq -r ".[$JSON_INDEX].run" "$JSON_FILE")
SIMJOB_SETUP=$(jq -r ".[$JSON_INDEX].simjob_setup" "$JSON_FILE")

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

# PushOutput
if [[ "$PUSHOUT" != true ]]; then
  echo "PushOutput disabled."
elif samweb locate-file "$parfile" &>/dev/null; then
  echo "Exists on SAM; not pushing."
else
  pushOutput outputs.txt
fi

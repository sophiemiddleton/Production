#!/usr/bin/env bash
# Author: Y. Oksuzian
# json2jobdef.sh: Unified generator for Stage1, Stage2(Resampler, Primaries), or Merge jobs via JSON
# Usage:
#   bash json2jobdef.sh --json config.json --desc <desc> [--owner mu2e] [--pushout]

# Defaults
OWNER=${USER/#mu2epro/mu2e}
JSON_FILE=""
JOB_DESC=""
PUSHOUT=false

usage() {
  cat <<EOF
Usage: $0 --json FILE --desc NAME [--owner NAME] [--pushout]

  --json       FILE   JSON config with job definitions (required)
  --desc       NAME   description key to select entry (required)
  --owner      NAME   data owner (default: mu2e)
  --pushout         enable pushOutput of results
  --help            show this message
EOF
  exit 1
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       JSON_FILE="$2"; shift 2;;
    --desc)       JOB_DESC="$2"; shift 2;;
    --owner)      OWNER="$2";    shift 2;;
    --pushout)    PUSHOUT=true;    shift;;
    --help)       usage;;
    *) echo "Unknown option: $1" >&2; usage;;
  esac
done

# Validate inputs
if [[ -z "$JSON_FILE" || -z "$JOB_DESC" ]]; then
  echo "Error: --json and --desc are required." >&2
  usage
fi

# Load JSON entry and ensure uniqueness
count=$(jq --arg d "$JOB_DESC" 'map(select(.desc==$d)) | length' "$JSON_FILE")
if (( count != 1 )); then
  echo "Error: found $count entries matching desc='$JOB_DESC'; must be exactly one." >&2
  exit 1
fi
entry=$(jq --arg d "$JOB_DESC" 'map(select(.desc==$d))[0]' "$JSON_FILE")

# Common fields
DSCONF=$(jq -r '.dsconf' <<<"$entry")
DESC=$(jq -r '.desc' <<<"$entry")
FCL=$(jq -r '.fcl // empty' <<<"$entry")
SIMJOB_SETUP=$(jq -r '.simjob_setup // empty' <<<"$entry")
INPUT_DATA=$(jq -r '.input_data // empty' <<<"$entry")
MERGE_FACTOR=$(jq -r '.merge_factor // empty' <<<"$entry")
RUN=$(jq -r '.run // empty' <<<"$entry")
EVENTS=$(jq -r '.events // empty' <<<"$entry")
RESAMPLER_NAME=$(jq -r '.resampler_name // empty' <<<"$entry")

# Initialize mu2ejobdef command
declare -a CMD=( mu2ejobdef --verbose --setup "$SIMJOB_SETUP"  --dsconf "$DSCONF" --desc "$DESC" --dsowner "$OWNER" )
# Only add run-number and events-per-job if exist in json
[[ -n "$RUN"    ]] && CMD+=( --run-number    "$RUN" )
[[ -n "$EVENTS" ]] && CMD+=( --events-per-job "$EVENTS" )

echo "Generating template.fcl with #include $FCL"
echo "#include \"$FCL\"" > template.fcl

if [[ -n "$INPUT_DATA" ]]; then
    echo "Listing files for input dataset: $INPUT_DATA"
    samweb list-files "dh.dataset=$INPUT_DATA and event_count>0" > inputs.txt
fi

# Job-specific logic
if [[ -n "$RESAMPLER_NAME" ]]; then
  echo "Resampler job: $DESC (${RESAMPLER_NAME})"
  nfiles=$(samCountFiles.sh "$INPUT_DATA")
  nevts=$(samCountEvents.sh "$INPUT_DATA")
  skip=$((nevts / nfiles))
  echo "physics.filters.${RESAMPLER_NAME}.mu2e.MaxEventsToSkip: $skip" >> template.fcl
  CMD+=( --auxinput "1:physics.filters.${RESAMPLER_NAME}.fileNames:inputs.txt" )
elif [[ -n "$MERGE_FACTOR" ]]; then
  echo "Merge job: $DESC, factor=$MERGE_FACTOR"
  CMD+=( --inputs inputs.txt --merge-factor "$MERGE_FACTOR" )
else
  echo "S1 job: $DESC"
fi

echo "Applying fcl_overrides to template.fcl"
jq -r --arg d "$JOB_DESC" \
  'map(select(.desc==$d))[0].fcl_overrides // {} | to_entries[] | "\(.key): \(.value)"' \
  "$JSON_FILE" >> template.fcl

# Finalize embed
echo "Embedding template.fcl"
CMD+=( --embed template.fcl )

# Echo and run
parfile="cnf.${OWNER}.${DESC}.${DSCONF}.0.tar"
rm -f $parfile
echo "${CMD[@]}"
"${CMD[@]}"

# pushOutput
echo "Post-processing outputs"
echo "disk $parfile none" > outputs.txt
if [[ "$PUSHOUT" == true ]]; then
  samweb locate-file "$parfile" &>/dev/null && echo "Exists on SAM; not pushing." || pushOutput outputs.txt
else
  echo "PushOutput disabled."
fi

# Generate test FCL
test_fcl="${parfile%.tar}.fcl"
mu2ejobfcl --jobdef "$parfile" --index 0 --default-proto root --default-loc tape > "$test_fcl"
cat "$test_fcl"

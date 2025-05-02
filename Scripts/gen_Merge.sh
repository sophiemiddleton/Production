#!/bin/bash
set -euo pipefail

# Default values
EMBED_FILE="Production/JobConfig/common/artcat.fcl"
INPUTS_FILE="./inputs.txt"
MERGE_FACTOR=10
SETUP_FILE=""
DESC=""
DSCONF=""
OWNER="mu2e"
DATASET=""
PUSHOUT=false  # Default: do not push output
JSON_FILE=""
JSON_INDEX=0
APPEND_LINES=()      # Collect lines to append to loc_template.fcl
EXTRA_OPTS=""       # Single string of additional mu2ejobdef options

# Function: Print usage message
usage() {
  cat << EOF
Usage: $0 [options]
Options:
  --fcl <file>               Path to the FCL file
  --inputs <file>            Path to the inputs file
  --merge-factor <num>       Merge factor
  --setup <file>             Path to the setup file
  --desc <desc>              Job description
  --dsconf <conf>            Dataset configuration
  --dsowner <owner>          Dataset owner
  --dataset <value>          Dataset string
  --append <line>            Append a line to loc_template.fcl (can be multiple)
  --extra-opt <opt>          Extra mu2ejobdef options (space-separated string)
  --prod                     Enable production mode
  --pushout                  Enable pushOutput
  --json <file>              Read parameters from JSON
  --json_index <num>         JSON index
  --help                     Show this help message
EOF
  exit 1
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fcl)         EMBED_FILE="$2"; shift 2;;
    --inputs)      INPUTS_FILE="$2"; shift 2;;
    --merge-factor) MERGE_FACTOR="$2"; shift 2;;
    --setup)       SETUP_FILE="$2"; shift 2;;
    --desc)        DESC="$2"; shift 2;;
    --dsconf)      DSCONF="$2"; shift 2;;
    --dsowner)     OWNER="$2"; shift 2;;
    --dataset)     DATASET="$2"; shift 2;;
    --append)      APPEND_LINES+=("$2"); shift 2;;
    --extra-opt)   EXTRA_OPTS="$2"; shift 2;;
    --prod)        PROD=true; shift 1;;
    --pushout)     PUSHOUT=true; shift 1;;
    --json)        JSON_FILE="$2"; shift 2;;
    --json_index)  JSON_INDEX="$2"; shift 2;;
    --help)        usage;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

# JSON overrides
if [[ -n "$JSON_FILE" ]]; then
  command -v jq >/dev/null || { echo "jq required"; exit 1; }
  DESC_JSON=$(jq -r ".[$JSON_INDEX].desc // empty" "$JSON_FILE")
  DSCONF_JSON=$(jq -r ".[$JSON_INDEX].dsconf // empty" "$JSON_FILE")
  DATASET_JSON=$(jq -r ".[$JSON_INDEX].dataset // empty" "$JSON_FILE")
  EMBED_FILE_JSON=$(jq -r ".[$JSON_INDEX].fcl // empty" "$JSON_FILE")
  SETUP_FILE_JSON=$(jq -r ".[$JSON_INDEX].simjob_setup // empty" "$JSON_FILE")
  MERGE_JSON=$(jq -r ".[$JSON_INDEX][\"merge-factor\"] // empty" "$JSON_FILE")
  [[ -n "$DESC_JSON" ]] && DESC="$DESC_JSON"
  [[ -n "$DSCONF_JSON" ]] && DSCONF="$DSCONF_JSON"
  [[ -n "$DATASET_JSON" ]] && DATASET="$DATASET_JSON"
  [[ -n "$EMBED_FILE_JSON" ]] && EMBED_FILE="$EMBED_FILE_JSON"
  [[ -n "$SETUP_FILE_JSON" ]] && SETUP_FILE="$SETUP_FILE_JSON"
  [[ -n "$MERGE_JSON" ]] && MERGE_FACTOR="$MERGE_JSON"
  if jq -e ".[$JSON_INDEX].append" "$JSON_FILE" >/dev/null; then
    mapfile -t JSON_APPEND < <(jq -r ".[$JSON_INDEX].append[]" "$JSON_FILE")
    APPEND_LINES+=("${JSON_APPEND[@]}")
  fi
  if jq -e ".[$JSON_INDEX].extra_opts" "$JSON_FILE" >/dev/null; then
    EXTRA_OPTS=$(jq -r ".[$JSON_INDEX].extra_opts" "$JSON_FILE")
  fi
fi

# Dataset parsing
if [[ -n "$DATASET" ]]; then
  IFS='.' read -r DATATIER_EX OWNER_EX DESC_EX DSCONF_EX SUFFIX <<< "$DATASET"
  OWNER="${OWNER:-$OWNER_EX}"
  DESC="${DESC:-$DESC_EX}"
  DSCONF="${DSCONF:-$DSCONF_EX}"
  DATATIER="${DATATIER:-$DATATIER_EX}"
  samweb list-definition-files "$DATASET" > "$INPUTS_FILE"
fi

# Report
echo "Opts: FCL=$EMBED_FILE inputs=$INPUTS_FILE merge=$MERGE_FACTOR setup=$SETUP_FILE desc=$DESC dsconf=$DSCONF owner=$OWNER extra_opts='$EXTRA_OPTS'"

# Prepare FCL
template="$MUSE_WORK_DIR/$(eval echo "$EMBED_FILE")"
cp "$template" loc_template.fcl
for ln in "${APPEND_LINES[@]}"; do echo "$ln" >> loc_template.fcl; done

# Run mu2ejobdef
cmd=(mu2ejobdef --verbose --embed loc_template.fcl --inputs "$INPUTS_FILE" \
     --merge-factor "$MERGE_FACTOR" --setup "$SETUP_FILE" \
     --desc "$DESC" --dsconf "$DSCONF" --dsowner="$OWNER")
# append extra opts string if non-empty
[[ -n "$EXTRA_OPTS" ]] && cmd+=( $EXTRA_OPTS )
echo "Running: ${cmd[*]}"
"${cmd[@]}"

# Display FCL
echo "--- loc_template.fcl ---"
sed -n '1,20p' loc_template.fcl

# Post-processing
echo "Generating job FCL and outputs"
parfile="cnf.${OWNER}.${DESC}.${DSCONF}.0.tar"
index_dataset="${parfile#cnf.}"; index_dataset="${index_dataset%.0.tar}"
test_fcl=cnf.${index_dataset}.fcl
mu2ejobfcl --jobdef "$parfile" --index 0 --default-proto root --default-loc tape > "$test_fcl"
cat "$test_fcl"
echo "disk $parfile none" > outputs.txt
if [[ "$PUSHOUT" != true ]]; then echo "PushOutput disabled.";
elif samweb locate-file "$parfile" >/dev/null 2>&1; then echo "Exists on SAM; not pushing.";
else pushOutput outputs.txt;
fi

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

# Function: Print usage message
usage() {
  cat << EOF
Usage: $0 [options]
Options:
  --fcl <file>           Path to the FCL file (default: \$MUSE_WORK_DIR/Production/JobConfig/common/artcat.fcl)
  --inputs <file>        Path to the inputs file (default: inputs.txt)
  --merge-factor <num>   Merge factor (default: 10)
  --setup <file>         Path to the setup file (default: /cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/%(release)s%(release_v_o)s/setup.sh)
  --desc <desc>          Job description
  --dsconf <conf>        Dataset configuration
  --dsowner <owner>      Dataset owner
  --dataset <value>      Dataset string (expected format: mcs.mu2e.<DESC>.<DSCONF>.art)
  --prod                 Enable production mode (create index definition to be used on the next stage)
  --pushout              Enable pushOutput (by default, pushOutput is disabled)
  --json <file>          Read parameters from a JSON file (see documentation)
  --json_index <num>     JSON index to use (0-indexed; default: 0)
  --help                 Show this help message
EOF
  exit 1
}

# Parse command-line options using a while loop
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fcl)
      EMBED_FILE="$2"
      shift 2
      ;;
    --inputs)
      INPUTS_FILE="$2"
      shift 2
      ;;
    --merge-factor)
      MERGE_FACTOR="$2"
      shift 2
      ;;
    --setup)
      SETUP_FILE="$2"
      shift 2
      ;;
    --desc)
      DESC="$2"
      shift 2
      ;;
    --dsconf)
      DSCONF="$2"
      shift 2
      ;;
    --dsowner)
      OWNER="$2"
      shift 2
      ;;
    --dataset)
      DATASET="$2"
      shift 2
      ;;
    --prod)
      PROD=true
      shift 1
      ;;
    --pushout)
      PUSHOUT=true
      shift 1
      ;;
    --json)
      JSON_FILE="$2"
      shift 2
      ;;
    --json_index)
      JSON_INDEX="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# If a JSON file is provided, use jq to override parameters (except owner)
if [[ -n "$JSON_FILE" ]]; then
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is not installed. Please install jq to use the --json option."
    exit 1
  fi
  # Extract parameters from the JSON file
  DESC_JSON=$(jq -r ".[$JSON_INDEX].desc" "$JSON_FILE")
  DSCONF_JSON=$(jq -r ".[$JSON_INDEX].dsconf" "$JSON_FILE")
  DATASET_JSON=$(jq -r ".[$JSON_INDEX].dataset" "$JSON_FILE")
  EMBED_FILE_JSON=$(jq -r ".[$JSON_INDEX].fcl" "$JSON_FILE")
  SETUP_FILE_JSON=$(jq -r ".[$JSON_INDEX].simjob_setup" "$JSON_FILE")
#  MERGE_FACTOR_JSON=$(jq -r ".[$JSON_INDEX].merge-factor" "$JSON_FILE")
  MERGE_FACTOR_JSON=$(jq -r ".[$JSON_INDEX][\"merge-factor\"]" "$JSON_FILE")

  # Override if JSON values are non-empty
  [[ -n "$DESC_JSON" && "$DESC_JSON" != "null" ]] && DESC="$DESC_JSON"
  [[ -n "$DSCONF_JSON" && "$DSCONF_JSON" != "null" ]] && DSCONF="$DSCONF_JSON"
  [[ -n "$DATASET_JSON" && "$DATASET_JSON" != "null" ]] && DATASET="$DATASET_JSON"
  [[ -n "$EMBED_FILE_JSON" && "$EMBED_FILE_JSON" != "null" ]] && EMBED_FILE="$EMBED_FILE_JSON"
  [[ -n "$SETUP_FILE_JSON" && "$SETUP_FILE_JSON" != "null" ]] && SETUP_FILE="$SETUP_FILE_JSON"
  [[ -n "$MERGE_FACTOR_JSON" && "$MERGE_FACTOR_JSON" != "null" ]] && MERGE_FACTOR="$MERGE_FACTOR_JSON"
fi

# If a dataset is provided, parse it to extract DESC, DSCONF, and OWNER (if not already set)
if [[ -n "$DATASET" ]]; then
  IFS='.' read -r DATATIER_EXTRACT OWNER_EXTRACT DESC_EXTRACT DSCONF_EXTRACT SUFFIX <<< "$DATASET"
  OWNER="${OWNER:-$OWNER_EXTRACT}"  # Use the parsed value only if OWNER is not set
  DESC="${DESC:-$DESC_EXTRACT}"
  DSCONF="${DSCONF:-$DSCONF_EXTRACT}"
  DATATIER="${DATATIER:-$DATATIER_EXTRACT}"

  samweb list-definition-files "$DATASET" > "$INPUTS_FILE"
fi

# Report the options being used
echo "Running mu2ejobdef command with the following options:"
echo "  FCL file:            $EMBED_FILE"
echo "  Inputs file:         $INPUTS_FILE"
echo "  Merge factor:        $MERGE_FACTOR"
echo "  Setup file:          $SETUP_FILE"
echo "  Job description:     $DESC"
echo "  Dataset configuration: $DSCONF"
echo "  Dataset owner:       $OWNER"
echo "  PushOutput enabled:  $PUSHOUT"
echo "  Datatier:            $DATATIER"

EMBED_FILE=$(eval echo "$EMBED_FILE")
echo "Copying fcl file: $EMBED_FILE"
echo "echo MUSE_WORK_DIR: $MUSE_WORK_DIR"
cp "$MUSE_WORK_DIR/$EMBED_FILE" loc_template.fcl

# If the FCL file contains "artcat.fcl", update parameters in the local template.
if [[ "$EMBED_FILE" == *"artcat.fcl"* ]]; then
  DESC="${DESC}Cat"
  {
    echo "physics.trigger_paths: []"
    echo "outputs.out.fileName: \"${DATATIER}.${OWNER}.${DESC}.${DSCONF}.SEQ.art\""
  } >> loc_template.fcl
fi

# Build the mu2ejobdef command as an array to preserve argument boundaries
cmd=(mu2ejobdef --verbose --embed loc_template.fcl --inputs "$INPUTS_FILE" --merge-factor "$MERGE_FACTOR" --setup "$SETUP_FILE" --desc "$DESC" --dsconf "$DSCONF" --dsowner "$OWNER")
echo "Running command: ${cmd[*]}"
"${cmd[@]}"

# Locate the parfile and extract an index dataset name using parameter expansion
parfile="cnf.${OWNER}.${DESC}.${DSCONF}.0.tar"
echo "parfile: $parfile"

# Query the number of jobs from the generated tar files
idx=$(mu2ejobquery --njobs "$parfile")
idx_format=$(printf "%07d" "$idx")

# Remove the "cnf." prefix and the trailing ".0.tar"
index_dataset="${parfile#cnf.}"
index_dataset="${index_dataset%.0.tar}"

# If production mode is enabled, source the additional index definition script
[ "${PROD:-false}" = true ] && source gen_IndexDef.sh

# Output the contents of the FCL file and the first few lines of the inputs file for verification
echo "FCL file content:"
echo "Inputs file content:"
head "$INPUTS_FILE"

test_fcl=cnf.${index_dataset}.fcl
mu2ejobfcl --jobdef $parfile --index 0 --default-proto root --default-loc tape > ${test_fcl}
cat ${test_fcl}

# Create outputs.txt with the specified content and optionally push output
echo "disk $parfile none" > outputs.txt

if [[ "$PUSHOUT" != true ]]; then
  echo "PushOutput disabled."
elif samweb locate-file "$parfile" >/dev/null 2>&1; then
  echo "File exists on SAM; not pushing output."
else
  pushOutput outputs.txt
fi



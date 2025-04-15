#!/bin/bash

# =============================
# Parse command line arguments
# =============================
LOCATION="scratch"
MERGE_FACTOR=10
MAX_TRIES=3
FCL_FILE=""
LOCAL_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --location)
      LOCATION="$2"
      shift 2
      ;;
    --merge-factor)
      MERGE_FACTOR="$2"
      shift 2
      ;;
    --fcl)
      FCL_FILE="$2"
      shift 2
      ;;
    --local)
      LOCAL_MODE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--location scratch|disk|tape] [--merge-factor N] [--fcl file.fcl] [--local]"
      exit 1
      ;;
  esac
done


# Function to end the SAM project process with a specified status
end_sam_project_process() {
  local status="$1"  # Status should be "completed" or "bad"
  echo ">>> Explicitly set process status to $status"
  ifdh setStatus "$SAM_PROJECT_URL" "$SAM_CONSUMER_ID" "$status"
  
  echo ">>> Ending SAM process"
  ifdh endProcess "$SAM_PROJECT_URL" "$SAM_CONSUMER_ID"
}


# =============================
# Validate required variables
# =============================
if [[ "$LOCATION" != "scratch" && "$LOCATION" != "disk" && "$LOCATION" != "tape" ]]; then
  echo "ERROR: Invalid location '$LOCATION'. Must be one of: scratch, disk, tape"
  exit 1
fi

if [[ -z "$SAM_DATASET" ]]; then
  echo "ERROR: SAM_DATASET is not set."
  exit 1
fi

if [[ "$LOCAL_MODE" == true && -z "$SAM_PROJECT_NAME" ]]; then
  # Generate a default project name
  SAM_PROJECT_NAME="local_${USER}_$(date +%Y%m%d_%H%M%S)"
  echo ">>> SAM_PROJECT_NAME not set. Using generated name: $SAM_PROJECT_NAME"
fi

echo ">>> Output location: $LOCATION"
echo ">>> Merge factor: $MERGE_FACTOR"
echo ">>> SAM_PROJECT_NAME: $SAM_PROJECT_NAME"
echo ">>> SAM_DATASET $SAM_DATASET"

[[ -n $FCL_FILE ]] && echo ">>> Using mu2e with FCL file: $FCL_FILE"

# =============================
# Environment setup
# =============================
echo ">>> Starting run_hadd_sam.sh"

export USER=${USER:-$(whoami)}
export IFDH_PASS_XROOTD=1
export HOSTNAME=${HOSTNAME:-$(hostname)}
export RELEASE=${RELEASE:-"NOT_SET"}
export CAMPAIGN=${POMS_CAMPAIGN_ID:-"NOT_SET"}
export JOBSUBJOBID=${JOBSUBJOBID:-"noGrid"}
export SAM_USER=${SAM_USER:-$USER}
export SAM_GROUP=${SAM_GROUP:-"mu2e"}
export SCHEMAS=${SCHEMAS:-"xroot"}

export IFDH_CP_MAXRETRIES=2
export IFDH_GRIDFTP_EXTRA="-st 60"



# ==========================================================
# Start or find SAM project and extract SAM_PROJECT_URL
# ==========================================================
if [[ "$LOCAL_MODE" == true ]]; then
  echo ">>> Starting SAM project locally with ifdh startProject"
  if ! SAM_PROJECT_URL=$(ifdh startProject "$SAM_PROJECT_NAME" mu2e "$SAM_DATASET" "$USER" mu2e 2> /dev/null); then
    echo "!!! Unable to start a SAM project. Error:"
    echo "$SAM_PROJECT_URL"
    exit 1
  fi
else
  echo ">>> Finding SAM project using ifdh findProject"
  if ! SAM_PROJECT_URL=$(ifdh findProject "$SAM_PROJECT_NAME" mu2e 2> /dev/null); then
    echo "!!! Unable to find a SAM project. Error:"
    echo "$SAM_PROJECT_URL"
    exit 1
  fi
fi

echo ">>> SAM_PROJECT_URL: $SAM_PROJECT_URL"

# =============================
# Establish SAM consumer process (with retries)
# =============================
RETRY_DELAY=5
tries=0

CMD=(ifdh establishProcess "$SAM_PROJECT_URL" mu2e "$RELEASE" "$HOSTNAME" "$USER" "$CAMPAIGN" "$JOBSUBJOBID" "$MERGE_FACTOR" "$SCHEMAS")
echo ">>> Running: ${CMD[*]}"

while [[ $tries -lt $MAX_TRIES ]]; do
  if SAM_CONSUMER_ID="$("${CMD[@]}" 2> /dev/null)"; then
    echo ">>> SAM_CONSUMER_ID = $SAM_CONSUMER_ID"
    break
  fi
  echo ">>> establishProcess failed, retrying ($tries)..."
  sleep $RETRY_DELAY
  ((tries++))
done

if [[ -z "$SAM_CONSUMER_ID" ]]; then
  echo "!!! Unable to establish a SAM process after $MAX_TRIES attempts."
  exit 1
fi

# =============================
# Fetch files from SAM
# =============================
FILES_DONE=0
INPUT_FILES=()

while [[ $FILES_DONE -lt $MERGE_FACTOR ]]; do
  FILE_URI=""
  tries=0

  while [[ $tries -lt $MAX_TRIES ]]; do
      
      FILE_URI=$(ifdh getNextFile "$SAM_PROJECT_URL" "$SAM_CONSUMER_ID")
#      FILE_URI=$(samweb get-next-file "$SAM_PROJECT_URL" "$SAM_CONSUMER_ID")
      rc=$?
      echo "get next file return code: $rc"
      
      [[ -n "$FILE_URI" ]] && break
      echo ">>> Empty FILE_URI, retrying ($tries)..."
      sleep 15
      ((tries++))
      
  done

  if [[ -z "$FILE_URI" ]]; then
    echo ">>> No more files from SAM after $MAX_TRIES tries"
    break
  fi

  LOCAL_FILE=$(basename "$FILE_URI")
  echo ">>> Got file: $FILE_URI"

  ifdh cp "$FILE_URI" .

  # Timeout ifdh cp after 5 mins
  # There is also XRD_REQUESTTIMEOUT flag
  IFDH_TIMEOUT_DURATION=500
  timeout $IFDH_TIMEOUT_DURATION ifdh cp "$FILE_URI" .

  # Capture the exit code
  rc=$?
  if [ $rc -eq 124 ]; then
      echo "Error: ifdh cp timed out after ${TIMEOUT_DURATION} seconds. Exiting."
      exit 1
  elif [ $rc -ne 0 ]; then
      echo "Error: ifdh cp failed with exit code $rc. Exiting."
      exit 1
  fi
  
  echo ">>> Fetched file: $LOCAL_FILE"
  if [[ ! -f $LOCAL_FILE ]]; then
      echo "!!! Failed to fetch file: $LOCAL_FILE"
      continue
  fi

  INPUT_FILES+=("$LOCAL_FILE")
  ((FILES_DONE++))
  ifdh updateFileStatus "$SAM_PROJECT_URL" "$SAM_CONSUMER_ID" "$LOCAL_FILE" consumed


done

ls -ltr

# Sort the INPUT_FILES array alphabetically
sorted_INPUT_FILES=($(printf "%s\n" "${INPUT_FILES[@]}" | sort))
INPUT_FILES=("${sorted_INPUT_FILES[@]}")

# =============================
# Validate file count
# =============================
if [[ ${#INPUT_FILES[@]} -lt $MERGE_FACTOR ]]; then
    echo "!!! ERROR: Expected $MERGE_FACTOR files but got ${#INPUT_FILES[@]}"
    echo "!!! ERROR: Mark sam project process as bad ... exiting."
    end_sam_project_process bad    
    exit 1
fi

# =============================
# Derive output filename
# =============================
first_file=$(basename "${INPUT_FILES[0]}")
IFS='.' read -ra PARTS <<< "$first_file"

if [[ ${#PARTS[@]} -eq 6 ]]; then
  OUTPUT_NAME="${PARTS[0]}.${PARTS[1]}.${PARTS[2]}Cat.${PARTS[3]}.${PARTS[4]}.${PARTS[5]}"
else
  echo "!!! ERROR: Unexpected filename format: $first_file"
  exit 1
fi

# =============================
# Run hadd or mu2e
# =============================
if [[ -n "$FCL_FILE" ]]; then
  CMD=(mu2e -c "$FCL_FILE" -s "${INPUT_FILES[@]}" -o "$OUTPUT_NAME")
  echo ">>> Running mu2e: ${CMD[*]}"
else
  CMD=(hadd -f "$OUTPUT_NAME" "${INPUT_FILES[@]}")
  echo ">>> Running hadd: ${CMD[*]}"
fi

if ! "${CMD[@]}"; then
  echo "!!! Command failed: ${CMD[*]}"
  exit 1
fi

# ========================================
# Bookkeeping and uploading via pushOutput
# ========================================
#PARENTS_DAT="parents.${OUTPUT_NAME%.root}.dat"
LOGFILE_LOC="log.${PARTS[1]}.${PARTS[2]}Cat.${PARTS[3]}.${PARTS[4]}.log"
PARENTS_DAT="parents_${PARTS[1]}.${PARTS[2]}Cat.${PARTS[3]}.${PARTS[4]}.dat"
printf "%s\n" "${INPUT_FILES[@]}" > "$PARENTS_DAT"

[[ $PROD == true ]] && cp "$jsb_tmp/$JOBSUB_LOG_FILE" "$LOGFILE_LOC"

echo "$LOCATION $OUTPUT_NAME $PARENTS_DAT" > output.txt
echo "disk $LOGFILE_LOC none" >> output.txt

pushOutput output.txt

# =============================
# Mark input files as consumed/completed
# =============================
for f in "${INPUT_FILES[@]}"; do
    echo ">>> Marking $f as completed"
    ifdh updateFileStatus "$SAM_PROJECT_URL" "$SAM_CONSUMER_ID" "$f" completed
done

# =====================================
# End sam project process as completed
# =====================================
end_sam_project_process completed

echo ">>> Finished"

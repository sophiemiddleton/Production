#!/usr/bin/env bash
#set -euo pipefail

PROD=false

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)
      PROD=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--prod] <merge_map_file>"
      exit 0
      ;;
    --*)
      echo "Unknown option: $1"
      echo "Usage: $0 [--prod] <merge_map_file>"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# Now we expect exactly one positional argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 [--prod] <merge_map_file>"
  exit 1
fi

INPUT_FILE="$1"
INPUT_NAME=$(basename "$INPUT_FILE")
INPUT_DIR=$(dirname "$INPUT_FILE")
OUTPUT_FILE="${INPUT_DIR}/merged_${INPUT_NAME}"

echo "Input file: $INPUT_FILE"
echo "Output file: $OUTPUT_FILE"

# Empty/initialize the output file.
> "$OUTPUT_FILE"

# Read each non-empty line in the merge map file.
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" ]] && continue

  read -r pardset override <<< "$line"
  if [ -z "$pardset" ] || [ -z "$override" ]; then
    echo "Line '$line' is not in the expected format '<pardset> <job_count>'"
    exit 1
  fi

  parfile="${pardset%.tar}.0.tar"
  echo "Processing file: $parfile"

  location=$(samweb locate-file "$parfile" 2>&1)
  if [ $? -ne 0 ]; then
    echo "Error executing samweb locate-file for $parfile: $location"
    exit 1
  fi

  location="${location#dcache:}"
  full_location="${location}/${parfile}"
  echo "Located file: ${full_location}"

  if [ "$override" -gt 0 ]; then
    job_count="$override"
  else
    job_count=$(mu2ejobquery --njobs "$full_location" 2>&1)
    if [ $? -ne 0 ]; then
      echo "Error executing mu2ejobquery for ${full_location}: $job_count"
      exit 1
    fi
  fi

  if ! [[ "$job_count" =~ ^[0-9]+$ ]]; then
    echo "Job count '$job_count' is not a valid integer for $parfile"
    exit 1
  fi

  echo "Job count for $parfile: $job_count"

  for (( i = 0; i < job_count; i++ )); do
    echo "${parfile} ${i}" >> "$OUTPUT_FILE"
  done

done < "$INPUT_FILE"

echo "Merge map generated successfully in '$OUTPUT_FILE'."

index_dataset=$(basename "${INPUT_FILE}")
echo "index_dataset: $index_dataset"

JOBS=$(wc -l < "$OUTPUT_FILE")
idx_format=$(printf "%07d" "${JOBS}")
echo "idx_format: $idx_format"

# Only source gen_IndexDef.sh if --prod was given
if [ "$PROD" = true ]; then
  samweb delete-definition "idx_$index_dataset"
  source gen_IndexDef.sh
fi

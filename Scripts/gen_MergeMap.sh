#!/usr/bin/env bash

# Check usage
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <merge_map_file>"
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
  # Skip blank lines.
  [[ -z "$line" ]] && continue

  # Expect each line to have two tokens: pardset and job_count_override.
  # Use read built-in to split the line into two variables.
  read -r pardset override <<< "$line"

  if [ -z "$pardset" ] || [ -z "$override" ]; then
    echo "Line '$line' is not in the expected format '<pardset> <job_count>'"
    exit 1
  fi

  parfile="${pardset%.tar}.0.tar"
  echo "Processing file: $parfile"

  # Get file location using samweb locate-file, capturing both stdout and stderr.
  location=$(samweb locate-file "$parfile" 2>&1)
  if [ $? -ne 0 ]; then
      echo "Error executing samweb locate-file for $parfile: $location"
      exit 1
  fi

  # Remove "dcache:" prefix if present.
  location="${location#dcache:}"
  echo "===="
  echo "Dir location: ${location}"
  echo "===="
  
  # Remove any trailing slash and append "/" + parfile.
  full_location="${location}/${parfile}"
  echo "Located file: ${full_location}"

  # Determine the number of jobs:
  # If override is > 0 use it directly; if not, query with mu2ejobquery.
  if [ "$override" -gt 0 ]; then
    job_count="$override"
  else
    job_count=$(mu2ejobquery --njobs "$full_location" 2>&1)
    if [ $? -ne 0 ]; then
      echo "Error executing mu2ejobquery for ${full_location}: $location"
      exit 1
    fi
  fi

  # Validate that job_count is an integer (only digits).
  if ! [[ "$job_count" =~ ^[0-9]+$ ]]; then
    echo "Job count '$job_count' is not a valid integer for $parfile"
    exit 1
  fi

  echo "Job count for $parfile: $job_count"

  # For each job index, output a line to the merge map.
  for (( i = 0; i < job_count; i++ )); do
    echo "${parfile} ${i}" >> "$OUTPUT_FILE"
  done

done < "$INPUT_FILE"

echo "Merge map generated successfully in '$OUTPUT_FILE'."

index_dataset=$(basename "${INPUT_FILE}")
echo "index_dataset: $index_dataset"

# Use input redirection so that wc outputs only the line count.
JOBS=$(wc -l < "$OUTPUT_FILE")
idx_format=$(printf "%07d" "${JOBS}")
echo "idx_format: $idx_format"

[ "$PROD" = true ] && source gen_IndexDef.sh


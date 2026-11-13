#!/bin/bash

# usage: "Stage6_blind_and_mix.sh 1 MDS2c" where first arg is ther iteration and second is the known tag

echo "=========================================="
echo "Stage 6: Blind and Mix"
echo "=========================================="
echo ""

i=$1
KNOWN=$2
CONFIG=${KNOWN}.txt

if [[ -z "$i" ]] || [[ -z "$KNOWN" ]]; then
  echo "ERROR: Missing arguments"
  echo "Usage: Stage6_blind_and_mix.sh <iteration> <known_tag>"
  echo "Example: Stage6_blind_and_mix.sh 1 MDS2c"
  exit 1
fi

echo "Input Parameters:"
echo "  Iteration: $i"
echo "  Known Tag: $KNOWN"
echo "  Config File: $CONFIG"
echo ""

BB=""
SIGNAL=""
RMUE=""

echo "Reading configuration from $CONFIG..."

while IFS='= ' read -r col1 col2
do 
    # Strip quotes from all values
    col2="${col2%\"}"
    col2="${col2#\"}"
    col2="${col2%\'}"
    col2="${col2#\'}"
    
    if [[ "${col1}" == "livetime_combined" ]] ; then
      LIVETIME=${col2}
    fi
    if [[ "${col1}" == "Rmue" ]] ; then
      RMUE=${col2}
    fi
    if [[ "${col1}" == "signal" ]] ; then
      SIGNAL=${col2}
    fi
    if [[ "${col1}" == "BB" ]] ; then
      BB=${col2}
    fi
done <${CONFIG}

echo "Configuration loaded:"
echo "  Livetime: $LIVETIME"
echo "  Rmue: $RMUE"
echo "  Signal: $SIGNAL"
echo "  Background (BB): $BB"
echo ""


INPUT_LIST="filenames_ChosenMixed_$i"
OUTPUT_LIST="merged_list_$i.txt"
OUTPUT_DIR="merged_files_$i"
OUTNAME="nts.mu2e.ensemble${KNOWN}Mix${BB}_${SIGNAL}_${RMUE}_${LIVETIME}.$i"

FILES_PER_MERGE=2 # Set the number of files to merge at a time

echo "Output Configuration:"
echo "  Input List: $INPUT_LIST"
echo "  Output Directory: $OUTPUT_DIR"
echo "  Output List: $OUTPUT_LIST"
echo "  Files per merge group: $FILES_PER_MERGE"
echo ""

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
echo "Created output directory: $OUTPUT_DIR"

# Clear the output list file before starting
> "$OUTPUT_LIST"
echo "Initialized output list: $OUTPUT_LIST"
echo ""
echo "Starting merge process..."
echo "=========================================="
echo ""

# --- Main Logic ---

# Use a while loop to read input files and an array to group them
file_group=()
counter=0
group_counter=1

while IFS= read -r root_file; do
  # Strip quotes from filenames
  root_file="${root_file%\"}"
  root_file="${root_file#\"}"
  root_file="${root_file%\'}"
  root_file="${root_file#\'}"
  
  # Skip empty lines
  [[ -z "$root_file" ]] && continue
  
  file_group+=("$root_file")
  counter=$((counter + 1))

  # Merge when the group is full or all files are processed
  if [[ ${#file_group[@]} -eq $FILES_PER_MERGE ]] || [[ -z "$root_file" && ${#file_group[@]} -gt 0 ]]; then
    
    # Define the output file name
    output_filename="${OUTPUT_DIR}/${OUTNAME}_${group_counter}.root"

    echo "[Group $group_counter] Merging ${#file_group[@]} files..."
    hadd -f -k "$output_filename" "${file_group[@]}"
    
    if [[ $? -eq 0 ]]; then
      echo "[Group $group_counter] ✓ Successfully created: $output_filename"
    else
      echo "[Group $group_counter] ✗ ERROR: Merge failed for group $group_counter"
      exit 1
    fi

    # Add the new file to the output list
    echo "$output_filename" >> "$OUTPUT_LIST"

    # Reset for the next group
    file_group=()
    group_counter=$((group_counter + 1))
  fi
done < "$INPUT_LIST"

# Check for any remaining files in the last group
if [[ ${#file_group[@]} -gt 0 ]]; then
  output_filename="${OUTPUT_DIR}/${OUTNAME}_${group_counter}.root"
  echo "[Group $group_counter] Merging final ${#file_group[@]} file(s)..."
  hadd -f -k "$output_filename" "${file_group[@]}"
  
  if [[ $? -eq 0 ]]; then
    echo "[Group $group_counter] ✓ Successfully created: $output_filename"
  else
    echo "[Group $group_counter] ✗ ERROR: Merge failed for final group"
    exit 1
  fi
  echo "$output_filename" >> "$OUTPUT_LIST"
fi

echo ""
echo "=========================================="
echo "Merge process complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  Total groups created: $group_counter"
echo "  Output directory: $OUTPUT_DIR"
echo "  Merged files list: $OUTPUT_LIST"
echo ""
echo "Next steps:"
echo "  1. Verify merged files in: $OUTPUT_DIR"
echo "  2. Check file list: $OUTPUT_LIST"
echo ""

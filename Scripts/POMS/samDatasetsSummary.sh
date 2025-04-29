#!/bin/bash

output_file="samDatasetSummary.csv"

# usage
if [[ -z "$1" ]]; then
  echo "Usage: $0 <dataset> OR <file.txt>" >&2
  exit 1
fi

# build list of datasets
if [[ -f "$1" ]]; then
  mapfile -t datasets < <(grep -vE '^\s*(#|$)' "$1")
  multi_mode=true
  echo "In multi-mode"
else
  datasets=( "$1" )
  multi_mode=false
  echo "In single-mode"
fi

# ensure CSV header exists
if [[ ! -f "$output_file" ]]; then
    rm -f $output_file
    echo "dataset_name,Trig,Gen events,nfiles" > "$output_file"
fi

for dataset in "${datasets[@]}"; do
    $multi_mode && echo "=== Dataset: $dataset ==="
    
    # sum of triggered events across all files
    triggered_sum=$(samweb list-files --summary "dh.dataset=${dataset}" | awk '/^Event/ { sum += $3 } END { print sum }')

    # total file count
    nfiles=$(samweb count-definition-files "$dataset")

    # sample size = min(nfiles,10)
    if (( nfiles < 10 )); then
	sample=$nfiles
    else
	sample=10
    fi

    # sum gencount over 'sample' files, extrapolate
    if (( sample > 0 )); then
	gencount_sum=$(samweb list-definition-files "$dataset" | head -n "$sample" \
			   | xargs -n1 samweb get-metadata \
			   | awk '/dh.gencount/ { sum += $2 } END { print sum }')
	total_events=$(( nfiles * gencount_sum / sample ))
    else
	exit 1
    fi

    printf "Triggered: %s\nGenerated: %s\nFiles: %s\n" "$triggered_sum" "$total_events" "$nfiles"

    # append to CSV
    echo "${dataset},${triggered_sum},${total_events},${nfiles}" >> "$output_file"

    $multi_mode && echo
done

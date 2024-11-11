#!/bin/bash

# Usage: ./script.sh [--include_empty] <dataset_definition>

if [[ "$1" == "--include_empty" ]]; then
    shift
    DATASET_DEF="$1"
    samweb count-files "defname: $DATASET_DEF"
else
    DATASET_DEF="$1"
    samweb count-files "defname: $DATASET_DEF and event_count>0"
fi

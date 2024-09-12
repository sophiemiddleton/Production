#!/bin/bash

# Default values
# Script to create par file and index dataset
EMBED_FILE="template.fcl"
INPUTS_FILE="inputs.txt"
MERGE_FACTOR=10
SETUP_FILE=""
DESC=""
DS_CONF=""
DS_OWNER=""
PROD=false

# Function: Print usage message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --embed <file>         Path to the template FCL file (default: template.fcl)"
    echo "  --inputs <file>        Path to the inputs file (default: inputs.txt)"
    echo "  --merge-factor <num>   Merge factor (default: 10)"
    echo "  --setup <file>         Path to the setup file (default: /cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/%(release)s%(release_v_o)s/setup.sh)"
    echo "  --desc <desc>          Job description"
    echo "  --dsconf <conf>        Dataset configuration"
    echo "  --dsowner <owner>      Dataset owner"
    echo "  --prod (opt) create index definition to be used on the next stage"

    exit 1
}

# Parse command line options
while getopts ":-:" options; do
  case ${options} in
    -)
      case "${OPTARG}" in
          embed)
              EMBED_FILE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          inputs)
              INPUTS_FILE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          merge-factor)
              MERGE_FACTOR=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          setup)
              SETUP_FILE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          desc)
              DESC=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          dsconf)
              DS_CONF=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          dsowner)
              DS_OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
          prod)
              PROD=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
              ;;
      esac;;
    :)                                    # If expected argument omitted:
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal                       # Exit abnormally.
      ;;
    *)                                    # If unknown (any other) option:
      exit_abnormal                       # Exit abnormally.
      ;;
  esac
done


# Run the merge command with the specified options
echo "Running mu2ejobdef  command with the following options:"
echo "  Embed file: $EMBED_FILE"
echo "  Inputs file: $INPUTS_FILE"
echo "  Merge factor: $MERGE_FACTOR"
echo "  Setup file: $SETUP_FILE"
echo "  Job description: $DESC"
echo "  Dataset configuration: $DS_CONF"
echo "  Dataset owner: $DS_OWNER"

if [[ "$PROD" = true ]]; then
    rm cnf.*.tar
fi

cmd="mu2ejobdef --verbose --embed $EMBED_FILE --inputs $INPUTS_FILE --merge-factor $MERGE_FACTOR --setup $SETUP_FILE --desc $DESC --dsconf $DS_CONF --dsowner $DS_OWNER"

echo "Running: $cmd"
$cmd

idx=$(mu2ejobquery --njobs cnf.*.tar)
idx_format=$(printf "%07d" $idx)

parfile=$(ls cnf.*.tar)
# Remove "cnf." string
index_dataset=${parfile:4}
# Remove .0.tar
index_dataset=${index_dataset::-6}

if [[ "$PROD" = true ]]; then
    source gen_IndexDef.sh
fi

echo "Embed file content:"
cat $EMBED_FILE
echo "Inputs file content:"
head $INPUTS_FILE

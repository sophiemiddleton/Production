#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g.  bash getLivetime.sh --filename filenames_CORSIKACosmic
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
FILENAME=""

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        filename)
          FILENAME=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        *)
          echo "Unknown option " ${OPTARG}
          exit_abnormal
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

mu2e -c /exp/mu2e/app/users/sophie/newOffline/Offline/Print/fcl/printCosmicLivetime.fcl -S ${FILENAME} | grep 'Livetime:' | awk -F: '{print $NF}' > ${FILENAME}.livetime
awk '{sum += $1} END {print "Total Livetime:", sum}' ${FILENAME}.livetime

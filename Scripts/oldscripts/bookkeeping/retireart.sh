#!/bin/bash

usage() { echo "Usage: $0
  [ --pname = process name
    --camp = campaign with db version and purpose
    --type = file family
    --run = runnumber
    --nfiles = total number of files
  ]
  e.g.  
  
  if mcs.mu2e.CeEndpointOnSpillSignal.MDC2020z_perfect_v1_1.001210_00000XXX.art
  
  then bash retireart.sh --pname CeEndpointOnSpillSignal --camp MDC2020z_perfect_v1_1 --run 1210 --nfiles 1000 --type mcs
  
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

PROCESSNAME=""
CAMPAIGN=""
TYPE=""
RUN=""
NFILES=""

while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        pname)
          PROCESSNAME=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        camp)
          CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        type)
          TYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        run)
          RUN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        nfiles)
          NFILES=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        *)
          echo "Unnown option " ${OPTARG}
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
echo ${NFILES}
for i in {00000001..00010000}; do samweb retire-file ${TYPE}.mu2e.${PROCESSNAME}.${CAMPAIGN}.00${RUN}_$i.art; done

#



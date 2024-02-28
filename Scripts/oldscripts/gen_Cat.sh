#!/usr/bin/bash
#
# Script to concatinate .art files

# The main input parameters needed for any campaign
NAME="" # is the primary
VERSION=""
CAMP=""
FILETYPE=""
OWNER="mu2e"
MERGE=1
SAMOPT="--schema=root"

# Function: Print a help message.
usage() {
  echo "Usage: $0
  [ --primary primary physics name ]
  [ --name name of the campaign]
  [ --camp primary campaign name]
  [ --version MDCVersion]
  [ --filetype dts,dig,mcs,sim etc ]
  [ --owner default mu2e ]
  [ --samopt for listing files ]
  [ --merge is 1 for Cat ]
  e.g. gen_Cat.sh --name CosmicCRYExtractedNoField --camp MDC2020 --version x --owner mu2e ]" 1>&2
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        name)
          NAME=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        camp)
          CAMP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        version)
          VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        filetype)
          FILETYPE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        samopt)
          SAMOPT=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        merge)
          MERGE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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

CONF=${CAMP}${VERSION}
OUTFILENAME="${FILETYPE}.DSOWNER.${NAME}Cat.DSCONF.SEQ.art"

samweb list-file-locations ${SAMOPT} --defname=${FILETYPE}.${OWNER}.${NAME}.${CONF}.art  | cut -f1  > inputs.txt
echo '#include "Production/JobConfig/common/artcat.fcl"' >> template.fcl
echo 'outputs.out.fileName: "'${OUTFILENAME}'"' >> template.fcl

generate_fcl --dsconf=${CONF} --dsowner=${OWNER} --description=${NAME}Cat  --inputs=inputs.txt --embed template.fcl --merge=${MERGE}
for dirname in 000 001 002 003 004 005 006 007 008 009; do
  if test -d $dirname; then
    echo "found dir $dirname"
    rm -rf ${NAME}\_$dirname
    mv $dirname ${NAME}\_$dirname
    echo "moving $dirname to ${NAME}_${dirname}"
  fi
done


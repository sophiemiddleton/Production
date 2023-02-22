#!/usr/bin/bash

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

usage() { echo "Usage:
  e.g.  bash generate_Reco.sh --primary CeEndpoint --release MDC2020 --dcamp MDC2020t --rcamp MDC2020t  --dbpurpose perfect --dbversion v1_0 --merge 10"
}

PRIMARY="" # name of primary
RELEASE="" # e.g. MDC2020
DIGI_CAMPAIGN="" # digi (input) campaign name
RECO_CAMPAIGN="" # reco (output) campaign name
DB_PURPOSE="" # db purpose  
DB_VERSION="" # db version
MERGE="" # merge factor
OWNER=mu2e


# Loop: Get the next option;
while getopts ":-:" options; do
  case "${options}" in      
    -)                                   
      case "${OPTARG}" in               
        primary)                                  
          PRIMARY=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))      
          ;;
        release)                                  
          RELEASE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))      
          ;;
        dcamp)                                   
          DIGI_CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                
          ;;
        rcamp)                                    
          RECO_CAMPAIGN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                  
          ;;
        dbpurpose)                                   
          DB_PURPOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                   
          ;;
        dbversion)                                   
          DB_VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                  
          ;;
        merge)                                   
          MERGE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                   
          ;;
        owner)                                   
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))                     
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

echo "Generating reco scripts for ${PRIMARY} conf ${DIGI_CAMPAIGN}_${DB_PURPOSE}_${DB_VERSION} output ${RECO_CAMPAIGN}_${DB_PURPOSE}_${DB_VERSION}  database purpose, version ${RECO_CAMPAIGN}_${DB_PURPOSE} ${DB_VERSION}"

samweb list-file-locations --schema=root --defname="dig.${OWNER}.${PRIMARY}.${DIGI_CAMPAIGN}_${DB_PURPOSE}_${DB_VERSION}.art"  | cut -f1 > Digis.txt

echo '#include "Production/JobConfig/reco/Reco.fcl"' > template.fcl
echo 'services.DbService.purpose:' ${RELEASE}'_'${DB_PURPOSE} >> template.fcl
echo 'services.DbService.version:' ${DB_VERSION} >> template.fcl
echo 'services.DbService.verbose : 2' >> template.fcl

generate_fcl --dsowner=${OWNER} --override-outputs --auto-description --embed template.fcl --dsconf "${RECO_CAMPAIGN}_${DB_PURPOSE}_${DB_VERSION}" \
--inputs "Digis.txt" --merge-factor=${MERGE}

base=${PRIMARY}Reco_
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
   echo "found dir $dirname"
   if test -d ${base}${dirname}; then
     echo "removing ${base}${dirname}"
     rm -rf ${base}${dirname}
   fi
  echo "moving $dirname to ${base}${dirname}"
  mv $dirname ${base}${dirname}
fi
done


#!/bin/bash

echo "=========================================="
echo "Stage 5: Signal Processing"
echo "=========================================="
echo ""

usage() { echo "Usage: $0
  e.g. Stage5_signal.sh --known MDS3a --rate 1e-13 --nexp 3 --mdsfiles nts.mu2e.ensembleMDS3cMix1BB.MDC2025-001.root
   --mdsmcs mcs.mu2e.ensembleMDS3cMix1BB.MDC2025am_best_v1_1.art --signalmcs mcs.mu2e.CeMLeadingLogMix1BBTriggered.MDC2025an_best_v1_3.art
  
  Required arguments:
  --known = known physics tag/name e.g. MDS3a
  --signal = signal dataset name e.g. CeMLeadingLogMix1BBTriggered
  --mdsfiles = full ntuple dataset name for known physics (e.g. nts.mu2e.ensemble...)
  --mdsmcs = full mcs dataset name for known physics (e.g. mcs.mu2e.ensemble_MDC2025af_best_v1_1.art)
  --signalmcs = full mcs dataset name for signal (e.g. mcs.mu2e.CeMLeadingLogMix1BBTriggered_MDC2025af_best_v1_1.art)
  
  Note: RELEASE, DBPURPOSE, and DBVERSION are automatically extracted from the dataset names
  
  Optional arguments:
  --owner = the username of your account (or mu2e if you are using mu2epro; default: mu2e)
  --rate = chosen rate e.g. 1e-14 (default: 1e-13)
  --nexp = number of sets of mixed samples or pseudo experiments (default: 1)
  --chooselivetime = chose a livetime in seconds e.g 86000
  
  NOTE: assumes signal and known are the same versions
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}
OWNER="mu2e"
KNOWN="MDS3a" #background sample tag
RATE=1e-13
SIGNAL="CeMLeadingLogMix1BBTriggered" #name as given to primary during production
RELEASE="" #extracted from dataset name
DBPURPOSE="" #extracted from dataset name
DBVERSION="" #extracted from dataset name
NEXP=1
CHOOSE=0.
EVENTNTUPLE="MDC2025-001"
MERGE=1
DUTY=0.323
RECOEFF=0.4009075 #correction factor to account for reconstruction efficiency of signal
MDSFILES="" #ntuple dataset for known physics
MDSMCS="" #mcs dataset for known physics sample
SIGNALMCS="" #mcs dataset for signal sample

while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        known)
          KNOWN=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        rate)
          RATE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        signal)
          SIGNAL=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
       nexp)
          NEXP=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        chooselivetime)
          CHOOSE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        mdsfiles)
          MDSFILES=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        mdsmcs)
          MDSMCS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        signalmcs)
          SIGNALMCS=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
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

# Validate required arguments
if [[ -z "$KNOWN" ]] || [[ "$KNOWN" == "MDS3a" ]]; then
  echo "ERROR: --known parameter is required and must not be the default value"
  exit_abnormal
fi

if [[ -z "$SIGNAL" ]] || [[ "$SIGNAL" == "CeMLeadingLogMix1BBTriggered" ]]; then
  echo "ERROR: --signal parameter is required and must not be the default value"
  exit_abnormal
fi

if [[ -z "$MDSFILES" ]]; then
  echo "ERROR: --mdsfiles parameter is required (full ntuple dataset name)"
  exit_abnormal
fi

if [[ -z "$MDSMCS" ]]; then
  echo "ERROR: --mdsmcs parameter is required (full mcs dataset name for known physics)"
  exit_abnormal
fi

if [[ -z "$SIGNALMCS" ]]; then
  echo "ERROR: --signalmcs parameter is required (full mcs dataset name for signal)"
  exit_abnormal
fi

# Extract RELEASE, DBPURPOSE, and DBVERSION from the dataset names
# Dataset format: mcs.mu2e.NAME.RELEASE_PURPOSE_VERSION.art or .root
TEMP_NAME="${SIGNALMCS##*/}"  # Remove path
TEMP_NAME="${TEMP_NAME%.art}" # Remove .art extension
TEMP_NAME="${TEMP_NAME%.root}" # Remove .root extension in case it's provided

# Extract the part after the last dot (should be RELEASE_PURPOSE_VERSION)
VERSION_PART="${TEMP_NAME##*.}"

# Split VERSION_PART by underscore - expecting: RELEASE_PURPOSE_VERSION
IFS='_' read -ra PARTS <<< "$VERSION_PART"
if [[ ${#PARTS[@]} -ge 3 ]]; then
  # Split into components: RELEASE PURPOSE VERSION
  RELEASE="${PARTS[0]}"
  DBPURPOSE="${PARTS[1]}"
  # Everything after PURPOSE is VERSION (in case it has multiple underscores like v1_3)
  DBVERSION="${PARTS[2]}"
  for ((j=3; j<${#PARTS[@]}; j++)); do
    DBVERSION+="_${PARTS[$j]}"
  done
else
  echo "ERROR: Could not parse RELEASE, DBPURPOSE, and DBVERSION from dataset name"
  echo "Expected format: mcs.mu2e.NAME.RELEASE_PURPOSE_VERSION.art"
  echo "Got: $SIGNALMCS"
  echo "Parsed VERSION_PART: $VERSION_PART"
  exit_abnormal
fi

echo "Input Parameters:"
echo "  Owner: $OWNER"
echo "  Known Physics: $KNOWN"
echo "  Signal: $SIGNAL"
echo "  Rate: $RATE"
echo "  Release: $RELEASE"
echo "  DB Purpose: $DBPURPOSE"
echo "  DB Version: $DBVERSION"
echo "  Number of Pseudo-experiments: $NEXP"
if [ "$CHOOSE" != "0." ]; then
  echo "  User-specified Livetime: $CHOOSE s"
fi
echo "  Known Physics Ntuple Dataset: $MDSFILES"
echo "  Known Physics MCS Dataset: $MDSMCS"
echo "  Signal MCS Dataset: $SIGNALMCS"
echo ""

# step 1: check livetime of the tag
echo "========================================="
echo "Step 1: Checking Livetime and Configuration"
echo "========================================="
echo ""
GEN_LIVETIME=""
GEN_JOBS=""
# extract config file from disk:
CONFIG=${KNOWN}.txt

echo "Loading configuration from $CONFIG..."
#echo "running: mu2eDatasetFileList cnf.${OWNER}.ensemble${KNOWN}.${RELEASE}${CURRENT}.txt"

#mu2eDatasetFileList cnf.${OWNER}.ensemble${KNOWN}.${RELEASE}${CURRENT}.txt >> config.txt
# Read each line (file path) from the input file
while IFS= read -r file_path; do
    if [ -f "$file_path" ]; then
        cp "$file_path" ${KNOWN}.txt
    fi
done < ${CONFIG}

while IFS='= ' read -r col1 col2
do 
    # Strip quotes from all values
    col2="${col2%\"}"
    col2="${col2#\"}"
    col2="${col2%\'}"
    col2="${col2#\'}"
    
    if [[ "${col1}" == "beam_livetime" ]] ; then
      GEN_LIVETIME=${col2}
      LIVETIME=${col2}
    fi
    if [[ "${col1}" == "njobs" ]] ; then
      GEN_JOBS=${col2}
    fi
    if [[ "${col1}" == "BB" ]] ; then
      BB=${col2}
    fi
    if [[ "${col1}" == "dutyfactor" ]] ; then
      DUTY=${col2}
    fi
    
done <${CONFIG}
echo "Configuration loaded:"
echo "  Generated Livetime: $GEN_LIVETIME s"
echo "  Background (BB): $BB"
echo "  Number of Jobs: $GEN_JOBS"
echo ""
rm -f *.csv
# if user has chosen to sample only a smaller amount of livetime then override
if (awk "BEGIN {exit !(${CHOOSE} != 0)}") ; then
  echo "User-specified livetime: ${CHOOSE} s"
  LIVETIME=${CHOOSE}
fi
if (awk "BEGIN {exit !(${CHOOSE} > ${GEN_LIVETIME})}") ; then
  echo "WARNING: User-specified livetime exceeds available sample size"
  echo "  Requested: ${CHOOSE} s"
  echo "  Available: ${GEN_LIVETIME} s"
  echo "  Defaulting to: ${GEN_LIVETIME} s"
  LIVETIME=${GEN_LIVETIME}
fi
echo "Livetime: ${LIVETIME} s (watch for potential changes)"
echo ""

# find how many known files are for livetime
echo "Calculating file requirements..."
N_TOTAL_KNOWN=496 #$(samDatasetsSummary.sh ${MDSMCS} | awk '/Files/ {print $2}')
echo "  Total known physics files available: $N_TOTAL_KNOWN"
LIVETIME_PER_FILE=$(awk "BEGIN {printf \"%.0f\", ${GEN_LIVETIME}/${N_TOTAL_KNOWN}}")
echo "  Livetime per file: ${LIVETIME_PER_FILE} s"
N_KNOWN_FILES_TO_USE=$(awk "BEGIN {printf \"%.0f\", ${LIVETIME}/${LIVETIME_PER_FILE}}")
echo "  Known physics files to use: ${N_KNOWN_FILES_TO_USE} (livetime: ${LIVETIME} s)"

# actual livetime that will be used for normalization of signal depends on int number of files
LIVETIME=$(awk "BEGIN {printf \"%.0f\", ${N_KNOWN_FILES_TO_USE}*${LIVETIME_PER_FILE}}")
echo ""
if (awk "BEGIN {exit !(${CHOOSE} != 0)}") ; then
  echo "IMPORTANT: Final livetime ${LIVETIME} s (adjusted for integer file requirement from user-specified ${CHOOSE} s)"
else
  echo "IMPORTANT: Final livetime ${LIVETIME} s (adjusted for integer file requirement)"
fi
echo ""

# understand how many events are present, and what fraction we need to sample
echo "========================================="
echo "Step 2: Signal Dataset Analysis"
echo "========================================="
echo ""
echo "Accessing signal dataset: mcs.mu2e.${SIGNAL}.${RELEASE}_${DBPURPOSE}_${DBVERSION}.art"
NGEN=10000000
#(samDatasetsSummary.sh mcs.mu2e.${SIGNAL}.${RELEASE}_${DBPURPOSE}_${DBVERSION}.art  | awk '/Generated/ {print $2}') 
#=10000000
echo "Signal sample contains ${NGEN} generated events"
echo ""

# recheck rate for new Nfiles
#RATE=$(calculateEvents.py --livetime ${LIVETIME} --BB ${BB} --nsig ${NSIG} --prc "GetRATE" )
#echo "can only sample full files, sampling ${N_SIGNAL_FILES_TO_USE} files so ${NSIG} and ${RATE}"

#need to store this somewhere, amend the .config and make an associated config for combined sample with nexp, rate, livetime_rate added at end of original.
echo "Saving combined configuration..."
echo "======= combined samples info =========" >> ${KNOWN}.txt
echo "signal= ${SIGNAL}">> ${KNOWN}.txt
echo "Rmue= ${RATE}">> ${KNOWN}.txt
echo "livetime_combined= ${LIVETIME}">> ${KNOWN}.txt
echo "npseudo_experiments= ${NEXP}">> ${KNOWN}.txt
echo ""

# build complete list
echo "========================================="
echo "Step 3: Building File Lists"
echo "========================================="
echo ""
echo "Cleaning up old file lists..."
rm -f filenames_All_${SIGNAL}
rm -f filenames_All_${KNOWN}
rm -f filenames_*
echo "Retrieving signal file list..."
echo "  Dataset: ${SIGNALMCS}"
mu2eDatasetFileList "${SIGNALMCS}" > filenames_All_${SIGNAL} 
echo "Retrieving known physics file list..."
echo "  Dataset: nts.mu2e.ensemble${TAG}Mix1BBTriggered.${EVENTNTUPLE}.root"
mu2eDatasetFileList ${MDSFILES} > filenames_All_${KNOWN}
echo ""


N_KNOWN_FILES_TO_USE=$(awk "BEGIN {printf \"%.0f\", ${N_KNOWN_FILES_TO_USE}/${MERGE}}")
echo "After merge factor (${MERGE}) applied: ${N_KNOWN_FILES_TO_USE} effective files"
echo ""

# step: split the signal files to get an exact number:
echo "========================================="
echo "Step 4: Processing Pseudo-experiments"
echo "========================================="
echo "Total pseudo-experiments to create: $NEXP"
echo ""
i=1
while [ $i -le ${NEXP} ]
do
  echo "[Pseudo-experiment $i/$NEXP]"
  # remove old files
  rm -f ntuple_$i.fcl
  rm -f splitter_$i.fcl
  
  # calculate yield of signal for chose rate, if > 0 then proceed --> use python scripts
  #BeamTime=$(awk "BEGIN {printf \"%.0f\", ${LIVETIME}*${DUTY}}")
  echo "  Calculating signal yield..."
  ONSPILLTIME=$(awk "BEGIN {printf \"%.0f\", ${LIVETIME}*${DUTY}}")
  NSIG=$(calculateEvents.py --livetime ${ONSPILLTIME} --prc "CeMLeadingLog" --BB ${BB} --rue ${RATE})
  echo "    Rate: ${RATE} | Background: ${BB} | Livetime: ${LIVETIME} s"
  echo "    Events to sample: ${NSIG}"
  NSIG=$(awk "BEGIN {printf \"%.0f\", ${NSIG}*${RECOEFF}}")
  echo "    After reconstruction efficiency correction (${RECOEFF}): ${NSIG} events"

  # calculate number of files
  echo "  Calculating file requirements..."
  N_TOTAL_SIGNAL=$(samDatasetsSummary.sh "${SIGNALMCS}" | awk '/Files/ {print $2}') #reconstructed signal files
  EVENTS_PER_FILE=$(awk "BEGIN {printf \"%.0f\", ${NGEN}/${N_TOTAL_SIGNAL}}") #generated events per file
  echo "    Total signal files: ${N_TOTAL_SIGNAL}"
  echo "    Generated events per file: ${EVENTS_PER_FILE}"
  N_SIGNAL_FILES_TO_USE=$(awk "BEGIN {printf \"%.0f\", ${NSIG}/${EVENTS_PER_FILE}}")
  
  # if its < 1 file the above will be 0, so we need to make sure we use at least 1 file here
  if (( N_SIGNAL_FILES_TO_USE == 0 )); then
    N_SIGNAL_FILES_TO_USE=1
    echo "    Files needed: 1 (minimum)"
  else
    echo "    Signal files to use: ${N_SIGNAL_FILES_TO_USE}"
  fi
  
  # build the splitter .fcl file and run on the chosen samples
  echo "  Selecting random signal files..."
  # randomly select a file here
  if [ ! -f "filenames_All_${SIGNAL}" ]; then
    echo "    ERROR: filenames_All_${SIGNAL} does not exist"
    exit 1
  fi
  shuf -n ${N_SIGNAL_FILES_TO_USE} "filenames_All_${SIGNAL}" > temp
  shuf temp > "filenames_ChosenSig_$i"
  rm temp
  # construct .fcl
  echo "  Building splitter configuration (splitter_$i.fcl)"
  if [ ! -w . ]; then
    echo "    WARNING: May lack permissions to write files"
  fi
  echo "#include \"Production/JobConfig/ensemble/fcl/split.fcl\"" >> splitter_$i.fcl
  
  echo "source.fileNames: [" >> splitter_$i.fcl
  while IFS= read -r line; do
    echo "\"$line\"" >> splitter_$i.fcl
    if (( ${N_SIGNAL_FILES_TO_USE} > 1 )); then
      echo "," >> splitter_$i.fcl
    fi
  done < "filenames_ChosenSig_$i"
  echo "]" >> splitter_$i.fcl
  echo "source.maxEvents: ${NSIG}" >> splitter_$i.fcl
  echo "outputs.out.fileName: \"mcs.mu2e.${SIGNAL}Split.${RELEASE}_${DBPURPOSE}_${DBVERSION}.${i}.art\"" >> splitter_$i.fcl
  echo "  Running signal splitter job..."
  cmd=$(mu2e -c splitter_$i.fcl)
  if [ $? -eq 0 ]; then
    echo "    ✓ Splitter job completed"
  else
    echo "    ✗ ERROR: Splitter job failed"
    exit 1
  fi
  $cmd
  
  # make the ntuples
  echo "  Building ntuple configuration (ntuple_$i.fcl)"
  echo "#include \"EventNtuple/fcl/from_mcs-mockdata.fcl\"" >> ntuple_$i.fcl
  echo "services.TFileService.fileName: \"nts.${OWNER}.${SIGNAL}Split.${RELEASE}_${DBPURPOSE}_${DBVERSION}.${i}.root\"" >> ntuple_$i.fcl
  cmd=$(mu2e -c ntuple_$i.fcl mcs.${OWNER}.${SIGNAL}Split.${RELEASE}_${DBPURPOSE}_${DBVERSION}.${i}.art)
  echo "  Running ntuple creation job..."
  if [ $? -eq 0 ]; then
    echo "    ✓ Ntuple creation completed"
  else
    echo "    ✗ ERROR: Ntuple creation failed"
    exit 1
  fi
  $cmd
  # Store the full absolute path to the signal ntuple file
  echo "$(pwd)/nts.${OWNER}.${SIGNAL}Split.${RELEASE}_${DBPURPOSE}_${DBVERSION}.${i}.root" > temp

  # create randomly mixed list of ntuples
  echo "  Creating mixed file list (signal + known physics)..."
  if [ ! -f "filenames_All_${KNOWN}" ]; then
    echo "    ERROR: filenames_All_${KNOWN} does not exist"
    exit 1
  fi
  shuf -n ${N_KNOWN_FILES_TO_USE} "filenames_All_${KNOWN}" >> temp
  shuf temp > "filenames_ChosenMixed_$i"
  rm temp
  echo "  ✓ Pseudo-experiment $i complete"
  echo ""
  i=$((i + 1))

done

echo "========================================="
echo "Cleanup and Finalization"
echo "========================================="
echo ""
echo "Moving .fcl files to fcl/ directory..."
mkdir -p fcl
mv *.fcl fcl
echo "Removing temporary files..."
rm -f *.csv
echo ""
echo "========================================="
echo "Stage 4 Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  Pseudo-experiments created: $NEXP"
echo "  Signal dataset: $SIGNAL"
echo "  Rate: $RATE"
echo "  Final livetime: ${LIVETIME} s"
echo ""
echo "Output files:"
echo "  Configuration: ${KNOWN}.txt"
echo "  FCL configs: fcl/"
echo "  File lists: filenames_ChosenMixed_*"
echo ""

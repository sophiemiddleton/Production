#!/usr/bin/bash
usage() { echo "Usage: $0
  e.g. Stage3_configure_ensemble_campaign.sh --tag MDS3c --release MDC2025 --version af
       Stage3_configure_ensemble_campaign.sh --tag MDS3c --release MDC2025 --version af --append
  
  --append: Skip TAR operations and just append stages to campaign JSON
"
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# Default values
TAG=""
RELEASE="MDC2025"
VERSION="au"
OWNER="mu2e"
APPEND=0

# Loop: Get the next option
while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        tag)
          TAG=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        release)
          RELEASE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        version)
          VERSION=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        owner)
          OWNER=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        append)
          APPEND=1
          ;;
        *)
          echo "Unknown option " ${OPTARG}
          exit_abnormal
          ;;
        esac;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)
      exit_abnormal
      ;;
    esac
done

# Validate required parameters
if [[ -z ${TAG} ]]; then
  echo "Error: --tag parameter is required"
  exit_abnormal
fi

# Check if append mode - if so, skip to campaign generation
if [[ ${APPEND} -eq 1 ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "📋 Stage 3 (Append Mode): Generating campaign JSON with all stages"
  echo "   Tag: ${TAG} | Release: ${RELEASE}${VERSION} | Owner: ${OWNER}"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  CAMPAIGN_JSON_FILE="MDC2025-${TAG}.json"
  
  echo "📋 [Append] Generating campaign JSON (with all stages)..."
  
  # Set default njobs if not provided
  njobs=${njobs:-100}
  
  # Create JSON for the campaign with all stages
  cat > ${CAMPAIGN_JSON_FILE} << CAMPAIGN_EOF
[
  {
    "desc": "ensemble${TAG}OnSpill",
    "dsconf": "${RELEASE}${VERSION}_best_v1_1",
    "fcl": "Production/JobConfig/digitize/OnSpill.fcl",
    "input_data": {
      "dts.mu2e.ensemble${TAG}.${RELEASE}${VERSION}.art": ${njobs}
    },
    "fcl_overrides": {
      "services.DbService.purpose": "Sim_best",
      "services.DbService.version": "v1_1",
      "outputs.Output.fileName": "dig.owner.{desc}.version.sequencer.art"
    },
    "inloc": "tape",
    "outloc": {"*.art": "tape"},
    "simjob_setup": "/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${RELEASE}${VERSION}/setup.sh"
  },
  {
    "desc": "ensemble${TAG}OnSpillReco",
    "dsconf": "${RELEASE}${VERSION}_best_v1_1",
    "fcl": "Production/JobConfig/recoMC/OnSpill.fcl",
    "input_data": {
      "dig.mu2e.ensemble${TAG}OnSpill.${RELEASE}${VERSION}_best_v1_1.art": 1
    },
    "fcl_overrides": {
      "services.DbService.purpose": "Sim_best",
      "services.DbService.version": "v1_1",
      "outputs.LoopHelixOutput.fileName": "mcs.owner.ensemble${TAG}OnSpill.version.sequencer.art"
    },
    "inloc": "tape",
    "outloc": {"*.art": "tape"},
    "simjob_setup": "/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${RELEASE}${VERSION}/setup.sh"
  },
  {
    "desc": "ensemble${TAG}Ntuple",
    "dsconf": ["${RELEASE}-001"],
    "fcl": ["EventNtuple/fcl/from_mcs-mockdata.fcl"],
    "input_data": {
      "mcs.mu2e.ensemble${TAG}OnSpill.${RELEASE}${VERSION}_best_v1_1.art": 1
    },
    "fcl_overrides": {
      "services.TFileService.fileName": "nts.mu2e.{desc}.version.sequencer.root"
    },
    "inloc": "tape",
    "outloc": {"*.root": "disk"},
    "simjob_setup": "/cvmfs/mu2e.opensciencegrid.org/Musings/AnalysisMDC2025/v02_00_00/setup.sh"
  }
]
CAMPAIGN_EOF

  if [[ ! -f ${CAMPAIGN_JSON_FILE} ]]; then
    echo "   ✗ Error: Failed to generate campaign JSON file"
    exit 1
  fi
  echo "   ✓ Generated ${CAMPAIGN_JSON_FILE}"
  echo ""
  echo "   To add additional stages (e.g. digi, reco, ntuple) to the existing ensemble campaign:"
  echo "     json2jobdef --json ${CAMPAIGN_JSON_FILE} --dsconf ${RELEASE}${VERSION}_best_v1_1 --desc ensemble${TAG}OnSpill --jobdefs /exp/mu2e/app/users/mu2epro/production_manager/poms_map/${CAMPAIGN_JSON_FILE} --prod"
  echo "     Then re-launch the campaign from the GUI"
  echo ""
  echo "   Note: This assumes production knowledge and access to POMS."
  echo "   Contact Production Manager if unsure of campaign setup and launch."
  echo ""

  
  echo "═══════════════════════════════════════════════════════════════"
  echo "✅ Append Complete!"
  echo "   Campaign: ${CAMPAIGN_JSON_FILE}"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📤 Stage 3: Upload TAR file to Storage"
echo "   Tag: ${TAG} | Release: ${RELEASE}${VERSION} | Owner: ${OWNER}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

TAR_FILE="cnf.${OWNER}.ensemble${TAG}.${RELEASE}${VERSION}.0.tar"
TAR_JSON_FILE="${TAR_FILE}.json"
CAMPAIGN_JSON_FILE="MDC2025-${TAG}.json"
CONFIG_FILE="${TAG}.txt"

echo "🔍 [1/4] Checking for TAR file and config..."
if [[ ! -f ${TAR_FILE} ]]; then
  echo "   ✗ Error: TAR file not found: ${TAR_FILE}"
  echo "   Make sure Stage 2 (Stage2_build_sampler.sh) has been run"
  exit 1
fi
if [[ ! -f ${CONFIG_FILE} ]]; then
  echo "   ✗ Error: Config file not found: ${CONFIG_FILE}"
  exit 1
fi
echo "   ✓ Found ${TAR_FILE}"
echo "   ✓ Found ${CONFIG_FILE}"
echo ""

echo "📋 [2/4] Generating TAR file metadata JSON..."
# Source the config file to get njobs
source ${CONFIG_FILE}

# Generate JSON from TAR file using printJson
echo "   Running printJson --no-parents on TAR file..."
printJson --no-parents ${TAR_FILE} > ${TAR_JSON_FILE}

if [[ ! -f "${TAR_JSON_FILE}" ]] || [[ ! -s "${TAR_JSON_FILE}" ]]; then
  echo "   ✗ Error: Failed to generate TAR JSON file"
  exit 1
fi
echo "   ✓ Generated ${TAR_JSON_FILE}"
echo ""

echo "📤 [3/4] Declaring and uploading TAR file..."
echo "   Declaring TAR JSON file to SAM..."
ls *.json | mu2eFileDeclare
if [[ $? -ne 0 ]]; then
  echo "   ✗ Error: Failed to declare TAR file"
  exit 1
fi
echo "   ✓ TAR file declared"
echo ""

echo "   Uploading TAR file to tape..."
UPLOAD_OUTPUT=$(ls *.tar | mu2eFileUpload --disk 2>&1)
if [[ ${PIPESTATUS[1]} -ne 0 ]]; then
  echo "   ✗ Error: Failed to upload TAR file"
  exit 1
fi

# Extract tape path from upload output (format: "filename to /pnfs/mu2e/..." )
TAPE_FILE=$(echo "${UPLOAD_OUTPUT}" | sed -n 's/.*to \(\/pnfs[^ ]*\).*/\1/p')

if [[ -z ${TAPE_FILE} ]]; then
  echo "   ✗ Error: Could not extract tape path from upload output"
  echo "   Output was: ${UPLOAD_OUTPUT}"
  exit 1
fi

# Get directory path (remove filename)
TAPE_PNFS=$(dirname "${TAPE_FILE}")
TAPE_PATH="enstore:${TAPE_PNFS}"

echo "   ✓ TAR file uploaded"
echo "   Tape location: ${TAPE_PNFS}"
echo ""

echo "   Adding file location to SAM..."
samweb add-file-location cnf.${OWNER}.ensemble${TAG}.${RELEASE}${VERSION}.0.tar ${TAPE_PATH}
if [[ $? -ne 0 ]]; then
  echo "   ✗ Error: Failed to add file location"
  exit 1
fi
echo "   ✓ File location registered"
echo ""

echo "📋 [3b/4] Processing tag information file..."
TAG_INFO_FILE="cnf.mu2e.${TAG}-info.${RELEASE}${VERSION}.0.txt"
TAG_INFO_JSON_FILE="${TAG_INFO_FILE}.json"

echo "   Renaming config file to tag-info..."
mv ${CONFIG_FILE} ${TAG_INFO_FILE}
if [[ ! -f ${TAG_INFO_FILE} ]]; then
  echo "   ✗ Error: Failed to rename config file to ${TAG_INFO_FILE}"
  exit 1
fi
echo "   ✓ Renamed to ${TAG_INFO_FILE}"
echo ""

echo "   Generating tag-info metadata JSON..."
printJson --no-parents ${TAG_INFO_FILE} > ${TAG_INFO_JSON_FILE}

if [[ ! -f "${TAG_INFO_JSON_FILE}" ]] || [[ ! -s "${TAG_INFO_JSON_FILE}" ]]; then
  echo "   ✗ Error: Failed to generate tag-info JSON file"
  exit 1
fi
echo "   ✓ Generated ${TAG_INFO_JSON_FILE}"
echo ""

echo "   Declaring tag-info JSON file to SAM..."
ls ${TAG_INFO_JSON_FILE} | mu2eFileDeclare
if [[ $? -ne 0 ]]; then
  echo "   ✗ Error: Failed to declare tag-info file"
  exit 1
fi
echo "   ✓ Tag-info file declared"
echo ""

echo "   Uploading tag-info file to tape..."
UPLOAD_TAG_OUTPUT=$(ls ${TAG_INFO_FILE} | mu2eFileUpload --disk 2>&1)
if [[ ${PIPESTATUS[1]} -ne 0 ]]; then
  echo "   ✗ Error: Failed to upload tag-info file"
  exit 1
fi

# Extract tape path from upload output
TAG_TAPE_FILE=$(echo "${UPLOAD_TAG_OUTPUT}" | sed -n 's/.*to \(\/pnfs[^ ]*\).*/\1/p')

if [[ -z ${TAG_TAPE_FILE} ]]; then
  echo "   ✗ Error: Could not extract tape path from upload output"
  echo "   Output was: ${UPLOAD_TAG_OUTPUT}"
  exit 1
fi

# Get directory path (remove filename)
TAG_TAPE_PNFS=$(dirname "${TAG_TAPE_FILE}")
TAG_TAPE_PATH="enstore:${TAG_TAPE_PNFS}"

echo "   ✓ Tag-info file uploaded"
echo "   Tape location: ${TAG_TAPE_PNFS}"
echo ""

echo "   Adding tag-info file location to SAM..."
samweb add-file-location ${TAG_INFO_FILE} ${TAG_TAPE_PATH}
if [[ $? -ne 0 ]]; then
  echo "   ✗ Error: Failed to add tag-info file location"
  exit 1
fi
echo "   ✓ Tag-info file location registered"
echo ""

echo "📋 [4/4] Generating campaign JSON (multipart stages)..."
# Create JSON for the campaign with all stages
cat > ${CAMPAIGN_JSON_FILE} << EOF
[
{
    "tarball": "${TAR_FILE}",
    "njobs": ${njobs},
    "inloc": "disk",
    "outputs": [
      {
        "dataset": "*.art",
        "location": "tape"
      }
    ]
  }
]
EOF

if [[ ! -f ${CAMPAIGN_JSON_FILE} ]]; then
  echo "   ✗ Error: Failed to generate campaign JSON file"
  exit 1
fi
echo "   ✓ Generated ${CAMPAIGN_JSON_FILE}"
echo ""
echo "   To run the ensembling campaign:"
echo "     1) Setup a new POMS campaign using the GUI"
echo "     2) Run: mkidxdef --jobdefs ${CAMPAIGN_JSON_FILE} --prod"
echo "     3) Launch the campaign from the GUI"
echo ""
echo "   To add additional stages (e.g. reco, ntuple):"
echo "     json2jobdef --json MDC2025-MDS3c.json --dsconf MDC2025ai_best_v1_1 --desc ensembleMDS3cOnSpill --jobdefs /exp/mu2e/app/users/mu2epro/production_manager/poms_map/${CAMPAIGN_JSON_FILE} --prod"
echo "     Then re-launch the campaign from the GUI"
echo ""
echo "   Note: This assumes production knowledge and access to POMS."
echo "   Contact Production Manager if unsure of campaign setup and launch."
echo ""



echo "═══════════════════════════════════════════════════════════════"
echo "✅ Stage 3 Complete!"
echo "   TAR file: cnf.${OWNER}.ensemble${TAG}.${RELEASE}${VERSION}.tar"
echo "   TAR metadata: cnf.${OWNER}.ensemble${TAG}.${RELEASE}${VERSION}.tar.json (declared and uploaded)"
echo "   Tag-info file: cnf.mu2e.tag-info.0.txt (declared and uploaded)"
echo "   Tag-info metadata: cnf.mu2e.tag-info.0.txt.json (declared and uploaded)"
echo "   Tape path (TAR): ${TAPE_PATH}"
echo "   Tape path (Tag-info): ${TAG_TAPE_PATH}"
echo "   Campaign: ${CAMPAIGN_JSON_FILE} (pending declaration)"
echo "   For ensemble generation enter mu2epro and launch: e.g. mkidxdef --jobdefs /exp/mu2e/app/users/mu2epro/production_manager/poms_map/MDC2025-MDS3b.json --prod"
echo "   For digi/mix/reco/ntuple enter mu2epro and launch: e.g. json2jobdef --json digi.json --dsconf MDC2025af_best_v1_3 --desc ensembleMDS3aOnSpill --jobdefs /exp/mu2e/app/users/mu2epro/production_manager/poms_map/MDC2025-002.json --prod"
echo "═══════════════════════════════════════════════════════════════"
echo ""

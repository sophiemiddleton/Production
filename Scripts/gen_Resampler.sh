#!/bin/bash
set -euo pipefail

# Default values
DESC=""                  # the desc
DSCONF=""                # dsconf (e.g. MDC2020ab)
RESAMPLER_NAME=""        # the kind of input stops (TargetStopResampler, TargetPiStopResampler)
RESAMPLER_DATA=""        # input dataset to resample
JOBS=""                  # number of jobs
EVENTS=""                # events per job

# Optional parameters
FLAT=""
PDG=11                   # pdgId for flat spectrum (default 11)
FIELD="Offline/Mu2eG4/geom/bfgeom_no_tsu_ps_v01.txt"  # optional field map override
STARTMOM=0               # for flat spectrum
ENDMOM=110               # for flat spectrum
OWNER="mu2e"
RUN=1202
SET_FNAMES=True

# New JSON option variables (defaults)
JSON_FILE=""
JSON_INDEX=0

# New pushout flag (default: pushOutput disabled)
PUSHOUT=false

# Function: Print a help message.
usage() {
  cat <<EOF
Usage: $0 [options]

Required:
  --desc             NAME   desc physics name
  --dsconf           NAME   dsconf label, e.g. MDC2020ap
  --resampler_name   NAME   Resampler module name
  --resampler_data   DATA   SAM dataset for resampler
  --njobs            N      Number of jobs
  --events           N      Events per job

Optional:
  --fcl              FILE   FCL file to #include
  --flat             STR    Flat spectrum option, e.g. FlatMuDaughter
  --pdg              PDG    PDGid of particles to process (default: 11)
  --start_mom        MOM    Start momentum (default: 0)
  --end_mom          MOM    End momentum (default: 110)
  --field            FILE   Overridden field map
  --owner            STR    (default: mu2e)
  --run              INT    (default: 1202)
  --simjob_setup     FILE   Setup script for simjob
  --set_fnames       TRUE   Append dts names to the file
  --json             FILE   Read parameters from a JSON file
  --json_index       N      Use the Nth JSON object (0-indexed; default: 0)
  --pushout          Enable pushOutput (by default, pushOutput is disabled)
  --help                    Print this help message
EOF
  exit 1
}

# Function: Exit with error.
exit_abnormal() {
  usage
  exit 1
}

# While-loop for command-line options
while [[ $# -gt 0 ]]; do
  key="$1"
  case "$key" in
    --fcl)
      FCL="$2"
      shift 2
      ;;
    --inputs)
      INPUTS_FILE="$2"
      shift 2
      ;;
    --merge-factor)
      MERGE_FACTOR="$2"
      shift 2
      ;;
    --setup)
      SETUP_FILE="$2"
      shift 2
      ;;
    --desc)
      DESC="$2"
      shift 2
      ;;
    --dsconf)
      DSCONF="$2"
      shift 2
      ;;
    --owner)
      OWNER="$2"
      shift 2
      ;;
    --resampler_name)
      RESAMPLER_NAME="$2"
      shift 2
      ;;
    --njobs)
      JOBS="$2"
      shift 2
      ;;
    --events)
      EVENTS="$2"
      shift 2
      ;;
    --resampler_data)
      RESAMPLER_DATA="$2"
      shift 2
      ;;
    --flat)
      FLAT="$2"
      shift 2
      ;;
    --pdg)
      PDG="$2"
      shift 2
      ;;
    --field)
      FIELD="$2"
      shift 2
      ;;
    --start_mom)
      STARTMOM="$2"
      shift 2
      ;;
    --end_mom)
      ENDMOM="$2"
      shift 2
      ;;
    --run)
      RUN="$2"
      shift 2
      ;;
    --simjob_setup)
      SIMJOB_SETUP="$2"
      shift 2
      ;;
    --set_fnames)
      SET_FNAMES="$2"
      shift 2
      ;;
    --json)
      JSON_FILE="$2"
      shift 2
      ;;
    --json_index)
      JSON_INDEX="$2"
      shift 2
      ;;
    --pushout)
      PUSHOUT=true
      shift 1
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# If a JSON file is provided, extract parameters using jq.
if [[ -n "$JSON_FILE" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Please install jq to use the --json option."
    exit_abnormal
  fi
  DSCONF=$(jq -r ".[$JSON_INDEX].dsconf" "$JSON_FILE")
  DESC=$(jq -r ".[$JSON_INDEX].desc" "$JSON_FILE")
  FCL=$(jq -r ".[$JSON_INDEX].fcl" "$JSON_FILE")
  RESAMPLER_NAME=$(jq -r ".[$JSON_INDEX].resampler_name" "$JSON_FILE")
  RESAMPLER_DATA=$(jq -r ".[$JSON_INDEX].resampler_data" "$JSON_FILE")
  JOBS=$(jq -r ".[$JSON_INDEX].njobs" "$JSON_FILE")
  EVENTS=$(jq -r ".[$JSON_INDEX].events" "$JSON_FILE")
  RUN=$(jq -r ".[$JSON_INDEX].run" "$JSON_FILE")
  STARTMOM=$(jq -r ".[$JSON_INDEX].start_mom" "$JSON_FILE")
  ENDMOM=$(jq -r ".[$JSON_INDEX].end_mom" "$JSON_FILE")
  SIMJOB_SETUP=$(jq -r ".[$JSON_INDEX].simjob_setup" "$JSON_FILE")
fi

# Basic tests for required parameters.
if [[ -z "$DSCONF" || -z "$DESC" || -z "$RESAMPLER_NAME" || -z "$JOBS" || -z "$EVENTS" ]]; then
  echo "Missing required arguments: dsconf, desc, resampler_name, njobs, or events."
  exit_abnormal
fi

echo "RESAMPLER_NAME: ${RESAMPLER_NAME}"
echo "Input dataset: $RESAMPLER_DATA"
samweb list-files "dh.dataset=$RESAMPLER_DATA and event_count > 0" > Stops.txt

# Calculate the max skip from the RESAMPLER_DATA
nfiles=$(samCountFiles.sh "$RESAMPLER_DATA")
nevts=$(samCountEvents.sh "$RESAMPLER_DATA")
nskip=$(( nevts / nfiles ))

# Write the template FCL file
rm -f primary.fcl
if [[ -n "$FCL" ]]; then
    echo "#include \"$FCL\"" > primary.fcl
else
    FCLNAME="${DESC%%_*}"
    echo "#include \"Production/JobConfig/primary/${FCLNAME}.fcl\"" > primary.fcl
fi
echo physics.filters.${RESAMPLER_NAME}.mu2e.MaxEventsToSkip: ${nskip} >> primary.fcl
echo "services.GeometryService.bFieldFile : \"${FIELD}\"" >> primary.fcl

# Append optional strings to primary.fcl
if [[ "${SET_FNAMES}" == "True" ]]; then
  echo outputs.PrimaryOutput.fileName: \"dts.owner.${DESC}.version.sequencer.art\" >> primary.fcl
  echo services.TFileService.fileName: \"nts.owner.GenPlots.version.sequencer.root\" >> primary.fcl
fi

if [[ "${DESC}" == "DIOtail"* ]]; then
  echo physics.producers.generate.decayProducts.spectrum.ehi: ${ENDMOM} >> primary.fcl
  echo physics.producers.generate.decayProducts.spectrum.elow: ${STARTMOM} >> primary.fcl
  echo physics.filters.GenFilter.maxr_min: 320 >> primary.fcl
  echo physics.filters.GenFilter.maxr_max: 500 >> primary.fcl
fi

if [[ "${FLAT}" == "FlatMuDaughter" ]]; then
  echo physics.producers.generate.pdgId: ${PDG} >> primary.fcl
  echo physics.producers.generate.startMom: ${STARTMOM} >> primary.fcl
  echo physics.producers.generate.endMom: ${ENDMOM} >> primary.fcl
fi

if [[ -n "$SIMJOB_SETUP" ]]; then
  echo "Using user-provided setup $SIMJOB_SETUP"
else
  SIMJOB_SETUP="/cvmfs/mu2e.opensciencegrid.org/Musings/SimJob/${DSCONF}/setup.sh"
fi

cat primary.fcl

# Mu2e jobdef command
cmd=(
  mu2ejobdef
  --verbose
  --embed primary.fcl
  --setup "$SIMJOB_SETUP"
  --run-number="$RUN"
  --events-per-job="$EVENTS"
  --desc "$DESC"
  --dsconf "$DSCONF"
  --auxinput="1:physics.filters.${RESAMPLER_NAME}.fileNames:Stops.txt"
)
echo "Running command: ${cmd[*]}"
"${cmd[@]}"

# Locate the parfile and extract an index dataset name using parameter expansion.
parfile="cnf.${OWNER}.${DESC}.${DSCONF}.0.tar"
echo "parfile: $parfile"

# Remove 'cnf.' prefix and trailing '.0.tar'
index_dataset=${parfile:4}
index_dataset=${index_dataset::-6}
idx_format=$(printf "%07d" "${JOBS}")

[ "${PROD:-false}" = true ] && source gen_IndexDef.sh

# Create outputs.txt with the specified content.
echo "disk $parfile none" > outputs.txt

# If pushout is enabled, check if the file exists on SAM. If not, perform pushOutput.
if [[ "$PUSHOUT" != true ]]; then
  echo "PushOutput disabled."
elif samweb locate-file "$parfile" >/dev/null 2>&1; then
  echo "File exists on SAM; not pushing output."
else
  pushOutput outputs.txt
fi

# Create a test FCL file.
test_fcl="cnf.${index_dataset}.fcl"
mu2ejobfcl --jobdef "$parfile" --index 1 --default-proto root --default-loc tape > "${test_fcl}"
cat "${test_fcl}"

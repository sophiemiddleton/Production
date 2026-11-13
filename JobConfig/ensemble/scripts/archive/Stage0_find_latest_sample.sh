#!/usr/bin/bash
usage() { echo "Usage: $0 --defname <samweb defname pattern with %> --release <release prefix>
  e.g. $0 --defname 'dts.mu2e.CosmicSignal%.MDC2025%.art' --release MDC2025

  Queries samweb for all SAM definitions matching --defname, extracts the
  version suffix that follows --release in each definition name (e.g. 'ac',
  'ag', 'au'), and prints the alphabetically latest version suffix plus the
  matching definition name.

  By default only the version suffix is written to stdout so this can be
  captured directly, e.g. VERSION=\$($0 --defname ... --release MDC2025).
  Use --verbose to also print progress/diagnostics (to stderr) and the full
  definition name.
"
}

exit_abnormal() {
  usage
  exit 1
}

DEFNAME=""
RELEASE="MDC2025"
VERBOSE=0

while getopts ":-:" options; do
  case "${options}" in
    -)
      case "${OPTARG}" in
        defname)
          DEFNAME=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        release)
          RELEASE=${!OPTIND} OPTIND=$(( $OPTIND + 1 ))
          ;;
        verbose)
          VERBOSE=1
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

if [[ -z ${DEFNAME} ]]; then
  echo "❌ Error: --defname is required" >&2
  exit_abnormal
fi

if ! command -v samweb &>/dev/null; then
  echo "❌ Error: samweb not found in PATH" >&2
  exit 1
fi

[[ ${VERBOSE} -eq 1 ]] && echo "🔍 Looking up definitions matching '${DEFNAME}'..." >&2

definitions=$(samweb list-definitions --defname="${DEFNAME}" 2>/dev/null)

if [[ -z "${definitions}" ]]; then
  echo "❌ Error: no SAM definitions matched pattern '${DEFNAME}'" >&2
  exit 1
fi

# Pair each definition with the version letters found after ${RELEASE}, then
# sort alphabetically (ac < ag < au) so the last line is the latest version.
result=$(
  while read -r defn; do
    [[ -z "${defn}" ]] && continue
    version=$(echo "${defn}" | grep -oP "${RELEASE}\K[a-z]+" | head -1)
    [[ -n "${version}" ]] && echo "${version} ${defn}"
  done <<< "${definitions}" | sort -k1,1 | tail -1
)

if [[ -z "${result}" ]]; then
  echo "❌ Error: could not parse a '${RELEASE}<version>' suffix from any matching definition" >&2
  exit 1
fi

LATEST_VERSION=$(echo "${result}" | awk '{print $1}')
LATEST_DEFNAME=$(echo "${result}" | awk '{print $2}')

if [[ ${VERBOSE} -eq 1 ]]; then
  echo "   ✓ Latest version: ${LATEST_VERSION}" >&2
  echo "   ✓ Definition:     ${LATEST_DEFNAME}" >&2
fi

echo "${LATEST_VERSION}"

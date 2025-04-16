#!/bin/bash
set -euo pipefail

# Default values
FILETYPE="art"    # Default filetype is "art"
DAYS=7            # Default days to look back
SUMMARY=false     # Default: do not print summary details
USER="mu2epro"    # Default user is mu2epro

# Process command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filetype)
      FILETYPE="$2"
      shift 2
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    --summary)
      SUMMARY=true
      shift 1
      ;;
    --user)
      USER="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--filetype <log|art>] [--days <number>] [--summary] [--user <username>]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--filetype <log|art>] [--days <number>] [--summary] [--user <username>]"
      exit 1
      ;;
  esac
done

# Calculate the date DAYS ago (in YYYY-MM-DD format)
OLDER_DATE=$(date -d "$DAYS days ago" +%Y-%m-%d)
echo "Checking for $FILETYPE files created after: $OLDER_DATE for user: $USER"

# Build the samweb query string using the chosen file type and user.
QUERY="Create_Date > $OLDER_DATE and file_format $FILETYPE and user $USER"

# Append a dot before the provided file type.
EXT=".$FILETYPE"

echo "------------------------------------------------"
echo "Grouped file counts:"
# Run the samweb query and process the output.
samweb list-files "$QUERY" | \
  awk -F. -v ext="$EXT" '{ print $1"."$2"."$3"."$4 ext }' | \
  sort | uniq -c
echo "------------------------------------------------"

# If the --summary flag is set, print detailed summary for each unique dataset group.
if [[ "$SUMMARY" == true ]]; then
  echo "Printing summary for each dataset group:"
  samweb list-files "$QUERY" | \
    awk -F. -v ext="$EXT" '{ print $1"."$2"."$3"."$4 ext }' | \
    sort | uniq | while read ds; do
      echo "------------------------------------------------"
      echo "Summary for dataset: $ds"
      samweb list-definition-files --summary "$ds"
  done
fi

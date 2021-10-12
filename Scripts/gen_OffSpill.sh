#!/usr/bin/bash
#
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
# $1 is the name of the primary (ie CeEndpoint, etc).
# $2 is the dataset description
# $3 is the campaign version of the input (primary) file
# $4 is the campaign version of the output (digi) file.
# $5 is the number of input collections to merge (merge factor)
rm template.fcl
samweb list-file-locations --schema=root --defname="dts.mu2e.$1.$2$3.art"  | cut -f1 > $1$3.txt
echo '#include "Production/JobConfig/digitize/OffSpill.fcl"' >> template.fcl
echo outputs.TriggeredOutput.fileName: \"dig.owner.${1}OffSpillTriggered.version.sequencer.art\" >> template.fcl
echo outputs.UntriggeredOutput.fileName: \"dig.owner.${1}OffSpillUntriggered.version.sequencer.art\" >> template.fcl
generate_fcl --dsconf="$2$4" --dsowner=mu2e --description="$1OffSpill" --embed template.fcl \
  --inputs="$1$3.txt" --merge-factor=$5
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf "$1OffSpill_$dirname"
  mv $dirname "$1OffSpill_$dirname"
 fi
done


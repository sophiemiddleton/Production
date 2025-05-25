#!/usr/bin/bash
#
# Script to create the SimEfficiency proditions content from a beam campaign.  The campaign 'configuration' field must be provided
# stopped pion campaign is the argument
rm $1_SimEff.txt
mu2eGenFilterEff --out=$1_SimEff.txt --chunksize=100 --firstLine "PionSimEfficiencies" --verbosity 3 sim.mu2e.PiBeamCat.$1.art sim.mu2e.PiTargetStops.$1.art 

#for  filter version you need the eventCount of sim.mu2e.PiTargetStops.$1.art as the denominator
PREFILTER=$(samDatasetsSummary.sh sim.mu2e.PiTargetStops.$1.art  | awk '/Triggered/ {print $2}')
FILTER=$(samDatasetsSummary.sh sim.mu2e.PiTargetFilt.$1.art  | awk '/Triggered/ {print $2}')
FILTEREFF=$(awk "BEGIN {printf \"%.5f\", ${FILTER}/${PREFILTER}}") 
echo "PiTargetFilt, ${PREFILTER}, ${FILTER}, ${FILTEREFF}" >> $1_SimEff.txt

TOTALWEIGHT=37468 #TODO need better way of adding to the file
SELECTEDWEIGHT=5.7055 #TODO need better way of adding to the file
echo "PiTotalLifeimeWeight,,,${TOTALWEIGHT}" >> $1_SimEff.txt
echo "PiSelectedLifeimeWeight,,,${SELECTEDWEIGHT}" >> $1_SimEff.txt

#!/usr/bin/bash
#
# Script to create the SimEfficiency proditions content from a beam campaign.  The campaign 'configuration' field must be provided
# stopped pion campaign is the argument
rm $1_SimEff.txt
mu2eGenFilterEff --out=$1_SimEff.txt --chunksize=100 
sim.mu2e.PiminusStopsCat.$1.art sim.mu2e.PiTargetStops.$1.art sim.mu2e.PiMinusFilter.$1.art
sed -i -e 's/dts\.mu2e\.//' -e 's/sim\.mu2e\.//' -e 's/\..*\.art//' -e 's/ IOV//' $1_SimEff.txt

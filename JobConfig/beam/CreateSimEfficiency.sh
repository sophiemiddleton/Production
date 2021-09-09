#!/usr/bin/bash
#
# Script to create the SimEfficiency proditions content from a beam campaign.  The campaign 'configuration' field must be provided
# as the first argument (ie MDC2020j)
#
rm $1_SimEff.txt 
mu2eGenFilterEff --out=$1_SimEff.txt sim.mu2e.MuBeamCat.$1.art sim.mu2e.EleBeamCat.$1.art sim.mu2e.NeutralsCat.$1.art \
sim.mu2e.MuminusStops.$1.art sim.mu2e.MuplusStops.$1.art sim.mu2e.IPAStopsCat.$1.art \
dts.mu2e.MuBeamFlashCat.$1.art dts.mu2e.EleBeamFlashCat.$1.art dts.mu2e.NeutralsFlashCat.$1.art \
dts.mu2e.MuStopPileupCat.$1.art \
dts.mu2e.EarlyMuBeamFlashCat.$1.art dts.mu2e.EarlyEleBeamFlashCat.$1.art dts.mu2e.EarlyNeutralsFlashCat.$1.art
sed -i -e 's/dts\.mu2e\.//' -e 's/sim\.mu2e\.//' -e 's/\..*\.art//' -e 's/Stops,/StopsCat,/'  -e 's/ IOV//' $1_SimEff.txt 

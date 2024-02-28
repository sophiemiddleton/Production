#!/bin/bash

samListLocations -f --schema=root --defname="sim.mu2e.CosmicDSStopsCORSIKA.MDC2020v.art" > files.txt
while IFS= read -r line
do
	echo "$line"
	gfal-copy $line gsiftp://dtn01.nersc.gov:2811/global/cfs/cdirs/m3249/mu2e
done < files.txt


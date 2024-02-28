#!/bin/bash


samListLocations -f --schema=root --defname="cnf.mu2e.CosmicCORSIKA.MDC2020v.fcl" > fclfiles.txt
while IFS= read -r line
do
	echo "$line"
	gfal-copy $line gsiftp://dtn01.nersc.gov:2811/global/cfs/cdirs/m3249/mu2e/datasets/CosmicCORSIKA/fcl
done < fclfiles.txt


#!/bin/bash

samweb list-files "dh.dataset=sim.mu2e.CosmicDSStopsCORSIKA.MDC2020v.art" > plainfiles.txt
while IFS= read -r line
do
	echo "$line"
	samweb add-file-location   $line  nersc:/global/cfs/cdirs/m3249/mu2e/datasets/CosmicDSStopsCORSIKA/art
done < plainfiles.txt


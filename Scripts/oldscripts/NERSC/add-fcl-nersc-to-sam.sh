#!/bin/bash

samweb list-files "dh.dataset=cnf.mu2e.CosmicCORSIKA.MDC2020v.fcl" > plainfiles.txt
while IFS= read -r line
do
	echo "$line"
	samweb add-file-location   $line  nersc:/global/cfs/cdirs/m3249/mu2e/datasets/CosmicCORSIKA/fcl
done < plainfiles.txt

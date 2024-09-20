#!/bin/bash

#file loops over set of files and removes datasets with 0 events

while IFS='= ' read -r col1
do 
    tester=$( ./../build/al9-prof-e28-p057/Offline/bin/eventCount ${col1})
    echo ${tester} >> output_pions-350ns-1merge.txt
done < 350ns-1merge.txt


while IFS='= ' read -r r1 r2 r3 r4 r5
do 
    if [[ "${r5}" != "0" ]] ; then
      echo ${r1} >> output_pions-350ns-1merge-no0_fnal.txt
      #echo ${r5} >> sum_it.txt
    fi
done < output_pions-350ns-1merge.txt

#echo "total " awk '{s+=$1} END {print s}' sum_it.txt



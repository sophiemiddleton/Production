#!/bin/bash
# This script runs generate_fcl N times shuffling the list of input files
# each time. It then moves all the FCL files to the current directory and rename
# them in sequential order.
# $1 input file
# $2 number of times to run generate_fcl
# $3 merge argument of generate_fcl
# $4 description argument of generate_fcl
# $5 dsconf argument of generate_fcl
# $6 dsowner argument of generate_fcl
# $7 embed argument of generate_fcl

if [[ $# -eq 0 ]] ; then
     usage='Usage:
catAndShuf.sh [inputFile] [nTimesGenerate_fcl] [merge] \
              [description] [dsconf] [dsowner] [embed]

This script runs generate_fcl N times shuffling the list of input files
each time. It then moves all the FCL files to the current directory and rename
them in sequential order. It needs the following arguments:
 - the name of file containing the inputs [inputFile]
 - the number of times to run generate_fcl [nTimesGenerate_fcl],
 - the merge argument of generate_fcl [merge],
 - the description argument of generate_fcl [description],
 - the dsconf argument of generate_fcl [dsconf],
 - the dsowner argument of generate_fcl [dsowner],
 - the embed argument of generate_fcl [embed].

 Example:
     catAndShuf.sh inputs.txt 10 100 EleBeamFlashCat MDC2020i mu2e template.fcl

 This will run generate_fcl 10 times with a merge factor of 100 shuffling the files
 in inputs.txt each time.'
     echo "$usage"
     exit 0
 fi

FILE=$1
ifile=0

for i in $(eval echo {1..$2})
do
    cat $1 | shuf > ${FILE%%.*}_shuf.txt

    generate_fcl --merge=$3 \
    --inputs=${FILE%%.*}_shuf.txt \
    --description=$4 \
    --dsconf=$5 \
    --dsowner=$6 \
    --embed $7

    FILES="[0-9]*/*.fcl"

    for f in $FILES
    do
        fields=(${f//./ })
        sequencer=${fields[4]}
        numbers=(${sequencer//_/ })
        counter_string_old=${numbers[1]}
        counter_string=$(printf "%08d" $ifile)
        sed -i "/outputs/s/$counter_string_old/$counter_string/g" $f
        sed -i "/dh.sequencer/s/$counter_string_old/$counter_string/g" $f.json
        sed -i "/file_name/s/$counter_string_old/$counter_string/g" $f.json
        mv "$f" `basename "${f/$counter_string_old/$counter_string}"`
        mv "$f.json" `basename "${f/$counter_string_old/$counter_string}.json"`
        ifile=$((ifile+1))
    done

    rm -rf [0-9]*
    rm ${FILE%%.*}_shuf.txt

done

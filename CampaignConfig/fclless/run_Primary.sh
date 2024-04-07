#!/bin/bash
echo "$(date) starting run_Primary"
echo "args: $@"
echo "fname=$fname"
echo "pwd=$PWD"
echo "ls of default dir"
ls -al
IND=$( echo $fname | awk -F. '{print $5}' | sed 's/^0*//' )
TARF=$(ls $CONDOR_DIR_INPUT/*.tar)
echo "IND=$IND TARF=$TARF"
mu2ejobfcl --parfile $TARF --index $IND --default-proto root --default-loc tape > temp.fcl
echo "$(date) run_Primary temp.fcl content"
cat temp.fcl
echo "$(date) run_Primary starting mu2e -c temp.fcl"
mu2e -c temp.fcl
echo "$(date) run_Primary starting mu2e -c temp.fcl"

#!/usr/bin/bash
# script to convert a PBI sequence in text format into art primaries
# you must have 'setup muse' in a valid directory to run this script
#
# $1 is the DocDB number from which the sequence is taken  (currently 33344)
# $2 is the PBI sequence type (either Normal or Pathological)
# $3 is the maximum number of events/job
# $4 is the run number
# $5 is the user field for the filename
# $6 is the description field for the filename
#
# Example:
# ./CreatePBISequence.sh 33344 Normal 1000 1201 mu2e MDC2020

infile=PBI_$2_$1.txt
nlines=`wc -l < $infile`
let nfiles=$nlines/$3
outroot=sim.$5.PBI$2_$1.$6.

echo "spliiting file $infile into $nfiles files"
split --lines $3 --numeric-suffixes --additional-suffix .txt $infile $outroot
#
# Now generate the fcl scripts to turn these into art files with PBI objects
#
for pbifile in $outroot*.txt; do
  fclfile=`echo ${pbifile} | sed s/txt/fcl/`
  artfile=`echo ${pbifile} | sed s/txt/art/`
  logfile=`echo ${pbifile} | sed s/txt/log/`
  echo '#include "Production/JobConfig/mixing/CreatePBISequence.fcl"' >> $fclfile
  echo source.fileNames : [ \"$pbifile\" ] >> $fclfile
  echo source.runNumber : $4 >> $fclfile
  echo outputs.Output.fileName : \"$artfile\" >> $fclfile
# now run the jobs
  echo creating art file $artfile
  mu2e -c $fclfile >& $logfile
  printJson --no-parents $artfile > $artfile.json
done



#!/usr/bin/bash
# script to create the fcl needed to convert a PBI sequence in text format into art primaries
# you must have 'setup muse' in a valid directory to run this script
#
# $1 is the DocDB number from which the sequence is taken  (currently 33344)
# $2 is the PBI sequence type (either Normal or Pathological)
# $3 is the maximum number of events/job
# $4 is the description field for the filename
#
# Example:
# source Production/Scripts/gen_NoPrimaryPBISequence.sh 33344 Normal 1000 MDC2020p

infile=/cvmfs/mu2e.opensciencegrid.org/DataFiles/PBI/PBI_$2_$1.txt
nlines=`wc -l < $infile`
let nfiles=$nlines/$3
outroot="dts.mu2e.PBI$2_$1.$4."
fclroot="cnf.mu2e.PBISequence_$2_$1.$4."
dirname="NoPrimaryPBISequence_$1_$2"
rm -rf $dirname
mkdir $dirname
cd $dirname

echo "spliiting file $infile into $nfiles files"
split --lines $3 --numeric-suffixes --additional-suffix .txt $infile $outroot
#
# Now generate the fcl scripts to turn these into art files with PBI objects
#
for pbifile in $outroot*.txt; do
  fclfile=`echo ${pbifile} | sed s/txt/fcl/ | sed s/dts/cnf/`
  artfile=`echo ${pbifile} | sed s/txt/art/`
  logfile=`echo ${pbifile} | sed s/txt/log/`
  echo '#include "Production/JobConfig/primary/NoPrimaryPBISequence.fcl"' >> $fclfile
  echo source.fileNames : [ \"${pbifile}\" ] >> $fclfile
  echo source.runNumber : 1202 >> $fclfile
  echo outputs.PrimaryOutput.fileName : \"$artfile\" >> $fclfile
# now run the jobs
  echo creating art file $artfile
  mu2e -c $fclfile >& $logfile
  printJson.sh --no-parents $artfile > $artfile.json
done
cd ../

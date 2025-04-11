# Generates the mixing fcl files for the STM campaign
# $1 is the production (e.g. MDC2020az)
# Original author: Pawel Plesniak

if [ -f tmp.fcl ]; then
  rm -f tmp.fcl
fi
nFiles=`wc -l merged.txt | cut -d ' ' -f1`
echo "Generating $nFiles jobs"
echo '#include "Offline/STMMC/fcl/CountMixedEvents.fcl"' > tmp.fcl
generate_fcl --dsconf=$1 --dsowner=plesniak --description=STMResampler --inputs=merged.txt --merge-factor=1 --embed tmp.fcl

for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf STMMixCounter_$dirname
  mv $dirname STMMixCounter_$dirname
  tmp=`ls -1 STMMixCounter_$dirname/*.fcl | wc -l`
 fi
done

# Cleanup
rm -f tmp.fcl
echo "Finished"

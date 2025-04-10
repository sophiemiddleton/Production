# Generates the mixing fcl files for the STM campaign
# $1 is the production (e.g. MDC2020az)
# $2 is the number of events per job
# Original author: Pawel Plesniak

if [ -f tmp.fcl ]; then
  rm -f tmp.fcl
fi
nFiles=`wc -l Ele.txt| cut -d ' ' -f1`
echo "Generating $nFiles jobs"
echo '#include "Offline/STMMC/fcl/Mix.fcl"' > tmp.fcl
outputJobs=0
tmp=0
generate_fcl --dsconf=$1 --dsowner=plesniak --run-number=1404 --description=STMResampler --events-per-job=$2 --njobs=$nFiles --embed tmp.fcl \
 --auxinput=1:physics.filters.STMStepMixerEle.fileNames:Ele.txt \
 --auxinput=1:physics.filters.STMStepMixerMu.fileNames:Mu.txt \
 --auxinput=1:physics.filters.STMStepMixer1809.fileNames:TS.txt

for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf STMMix_$dirname
  mv $dirname STMMix_$dirname
  tmp=`ls -1 STMMix_$dirname/*.fcl | wc -l`
  outputJobs=$((outputJobs+tmp))
 fi
done
echo "Generated $outputJobs jobs"

# Cleanup
echo "Removing temporary files"
rm -f tmp.fcl
echo "Finished"

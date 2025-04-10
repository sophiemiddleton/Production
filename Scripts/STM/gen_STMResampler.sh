#!/usr/bin/bash
# Generate fcl files for resampling the hits generated with BeamToVD101.fcl
# Pawel Plesniak

# $1 is the production (ie MDC2020)
# $2 is the input production version
# $3 is the output production version
# $4 is the number of jobs
# $5 is the project name of the BeamToVD101.fcl grid job. If not given, then it is assumed that the text file containing all the input datasets
#    are listed in a file called STMDatasetList.txt with a single line at the end containing the number of events in the named STMDatasetList.txt.
#    This works under the assumption that all jobs in the output directory are associated with the BeamToVD101.fcl grid job

if [[ ${4} == "" ]]; then
  echo "Missing arguments!"
  return -1
fi

# TODO BEFORE NEXT CAMPAIGN - rewrite this to use the SAM tools samCountFiles.sh and samCountEvents.sh
# Create the input dataset list STMDatasetList.txt
if [[ ${5} != "" ]]; then
  jobDir="/pnfs/mu2e/scratch/users/"$USER"/workflow/"$5"/outstage/*/*/*/*.art"
  echo "Generating STMDatasetList.txt"
  if [ -f STMDatasetList.txt ]; then
    echo "Removing pre-existing STMDatasetList.txt"
    rm STMDatasetList.txt;
  fi
  echo "Finding all the input datasets"
  echo "Note - this is likely to take approx one minute."
  find $jobDir -type f -name "*.art" > STMDatasetList.txt;
  echo "Running Offline/Print/fcl/count.fcl -S STMDatasetList.txt"
  echo "Note - this is likely to take a few mins especially if there are a lot of files"
  tail=`mu2e -c Offline/Print/fcl/count.fcl -S STMDatasetList.txt | tail -n 30 | grep "Event records" | xargs`
  tailArray=($tail)
  nEvents=${tailArray[0]}
  echo ${nEvents} >> STMDatasetList.txt
  echo "Finished generating STMDatasetList.txt"
else
  echo "Using existing STMDatasetList.txt"
  if [ ! -f STMDatasetList.txt ]; then
      echo "No dataset list file called STMDatasetList.txt, exiting"
      exit 1
  fi
  nEvents=`tail -n 1 STMDatasetList.txt | xargs`
fi

# Count the number of jobs and files
nFiles=`wc -l STMDatasetList.txt`
nFiles=($nFiles)
nFiles=$((nFiles[0]-1))
nSkip=$((nEvents/nFiles))
echo "Found $nEvents events over $nFiles files. Setting MaxEventsToSkip as $nSkip"

# Create a copy of STMDatasetList.txt without the event count at the end
if [ -f STMDatasetListNoCount.txt ]; then
  echo "Removing pre-existing STMDatasetListNoCount.txt"
  rm -f STMDatasetListNoCount.txt
fi
head -n ${nFiles} STMDatasetList.txt > STMDatasetListNoCount.txt

# write the template fcl
rm -f stmResampler.fcl
echo '#include "Production/JobConfig/pileup/STM/STMResampler.fcl"' >> stmResampler.fcl
echo physics.filters.stmResampler.mu2e.MaxEventsToSkip: ${nSkip} >> stmResampler.fcl

generate_fcl --dsconf=$1$3 --dsowner=plesniak --run-number=1404 --description=STMResampler --events-per-job=20000000000 --njobs=$4 \
  --embed stmResampler.fcl --auxinput=1:physics.filters.stmResampler.fileNames:STMDatasetListNoCount.txt # --old-seeds=seeds.plesniak.EleBeamResamplerSTM.MDC2020ab.CkMv.txt

for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf STMResampler_$dirname
  mv $dirname STMResampler_$dirname
 fi
done

# Cleanup
echo "Removing temporary files"
rm -f STMDatasetListNoCount.txt
rm -f stmResampler.fcl
echo "Finished"

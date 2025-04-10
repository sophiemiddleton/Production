# Generates the concatenation fcl files for the STM campaign
# $1 is the dsconf
# $2 is the .txt file with the list of EleBeamCat derived files with StepPointMCs in STMDet
# $3 is the number of EleBeamCat derived files to mix into a single file
# $4 is the .txt file with the list of MuBeamCat derived files with StepPointMCs in STMDet
# $5 is the number of MuBeamCat derived files to mix into a single file
# $6 is the .txt file with the list of TargetStopsCat derived files with StepPointMCs in STMDet
# Original author: Pawel Plesniak

# if [[ ${7} == "" ]]; then
#   echo "Missing arguments!"
#   return -1
# fi

if [ -f tmp.fcl ]; then
  rm -f tmp.fcl
fi
echo '#include "Offline/STMMC/fcl/Concatenate.fcl"' >> tmp.fcl
tmp=0

nEleFiles=`wc -l $2 | cut -d ' ' -f1`
nEleJobs=$((1+nEleFiles/$3))
outputJobs=0
echo "EleBeamCat: generating $nEleJobs jobs each with $3 input files from $nEleFiles input files"
generate_fcl --dsconf=$1 --dsowner=plesniak --description=STMConcat --inputs=$2 --merge-factor=$3 --embed tmp.fcl
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  rm -rf STMCatEle_$dirname
  mv $dirname STMCatEle_$dirname
  tmp=`ls -1 STMCatEle_$dirname/*.fcl | wc -l`
  outputJobs=$((outputJobs+tmp))
 fi
done
echo "Generated $outputJobs files"

nMuFiles=`wc -l $4 | cut -d ' ' -f1`
nMuJobs=$((1+nMuFiles/$5))
outputJobs=0
echo "MuBeamCat: generating $nMuJobs jobs each with $5 input files from $nMuFiles input files"
generate_fcl --dsconf=$1 --dsowner=plesniak --description=STMConcat --inputs=$4 --merge-factor=$5 --embed tmp.fcl
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  rm -rf STMCatMu_$dirname
  mv $dirname STMCatMu_$dirname
  tmp=`ls -1 STMCatMu_$dirname/*.fcl | wc -l`
  outputJobs=$((outputJobs+tmp))
 fi
done
echo "Generated $outputJobs files"

nTSFiles=`wc -l $6 | cut -d ' ' -f1`
nTSJobs=$((1+nEleFiles/$7))
outputJobs=0
echo "TargetStopsCat: generating $nTSJobs jobs each with $7 input files from $nTSFiles input files"
generate_fcl --dsconf=$1 --dsowner=plesniak --description=STMConcat --inputs=$6 --merge-factor=$7 --embed tmp.fcl
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  rm -rf STMCatTS_$dirname
  mv $dirname STMCatTS_$dirname
  tmp=`ls -1 STMCatTS_$dirname/*.fcl | wc -l`
  outputJobs=$((outputJobs+tmp))
 fi
done
echo "Generated $outputJobs files"

# Cleanup
rm -f tmp.fcl
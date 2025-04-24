# Counts the number of mixed EleBeamCat events generated with Offline/STMMC/fcl/Mix.fcl
# Takes one parameter - the list of logfiles generated from the mixing
# Original author: Pawel Plesniak

if [[ ${1} == "" ]]; then
  echo "Missing argument!"
  return -1
fi

nEleBeamCat=0
nMuBeamCat=0
nTargetStopsCat=0

while IFS= read -r filename; do
    n=`grep 'EleBeamCat' $filename | cut -d ' ' -f2`
    nEleBeamCat=$((nEleBeamCat+n))
    n=`grep 'MuBeamCat' $filename | cut -d ' ' -f2`
    nMuBeamCat=$((nMuBeamCat+n))
    n=`grep 'TargetStopsCat' $filename | cut -d ' ' -f2`
    nTargetStopsCat=$((nTargetStopsCat+n))
done < $1

echo "Mixed EleBeamCat events: $nEleBeamCat"
echo "Mixed MuBeamCat events: $nMuBeamCat"
echo "Mixed TargetStopsCat events: $nTargetStopsCat"
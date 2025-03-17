# Generate HPGe waveforms and analyze them to generate their spectra using the results from Production/JobConfig/pileup/STM/STMResampler.fcl
# Original author: Pawel Plesniak
# $1 is the output production (e.g. MDC2020az)
# $2 is the name of the file containing all the mixed files generated with Offline/STMMC/fcl/Mix.fcl
# Original author: Pawel Plesniak

if [[ ${2} == "" ]]; then
  echo "Missing arguments!"
  return -1
fi

# create the input list
# write the mubeamresampler.fcl
rm -f mubeamresampler.fcl
echo '#include "Offline/STMMC/fcl/HPGeReco.fcl"' >> HPGeDigi.fcl
#
generate_fcl --dsconf=$1 --dsowner=mu2e --description=HPGeReco --input=$2 --merge-factor=1 --embed HPGeDigi.fcl
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf STMHPGeDigi_$dirname
  mv $dirname STMHPGeDigi_$dirname
 fi
done

echo "Removing temporary files"
rm -f HPGeDigi.fcl
echo "Finished"

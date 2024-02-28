#!/bin/bash -x
echo mu2e "$@"
pwd
ls
# file name is taken as input arguement:
filespec=${@: -1}
filename=`basename $filespec`
echo $filename
# New code:
INURL=$( fhicl-get physics.filters.CosmicResampler.fileNames $filespec --sequence-of string )
echo "INURL" $INURL
INFN=$(basename $INURL)
echo "INFN" $INFN
ifdh cp $INURL ./$INFN
sed -i 's|'$INURL'|'$INFN'|' $filespec
cat $filespec
ls -al
# end New code:
logFilename=${filename/cnf./log.}
logExtension=${logFilename/.fcl/.txt}
tbzFilename=${filename/cnf./bck.}
tbzExtension=${tbzFilename/.fcl/.tbz}
# write output to logExtension
mu2e "$@" |& tee ${logExtension}
# what does grep return? save as status
mu2e_exit_status=${PIPESTATUS[0]}
# tar files including logs
tar -cvjf ${tbzExtension} ${logExtension}
tar_exit_status=${?}
exit ${mu2e_exit_status}

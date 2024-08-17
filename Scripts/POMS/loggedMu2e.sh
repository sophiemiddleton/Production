#!/bin/bash -x
echo mu2e "$@"
pwd
ls
filename=`basename ${@: -1}`
echo $filename
logFilename=${filename/cnf./log.}
logExtension=${logFilename/.fcl/.txt}
tbzFilename=${filename/cnf./bck.}
tbzExtension=${tbzFilename/.fcl/.tbz}
mu2e "$@" |& tee ${logExtension}
mu2e_exit_status=${PIPESTATUS[0]}
tar -cvjf ${tbzExtension} ${logExtension} ${filename}
tar_exit_status=${?}
exit ${mu2e_exit_status}

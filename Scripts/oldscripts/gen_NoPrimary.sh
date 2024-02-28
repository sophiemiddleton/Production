#!/usr/bin/bash
#
# create fcl for producing NoPrimary events
# this script requires mu2etools be setup
#
# $1 is the production (ie MDC2020)
# $2 is the output primary production version
# $3 is the number of jobs
# $4 is the number of events/job
if [[ $# -lt 4 ]]; then
  echo "Missing arguments, provided $# but there should be 5"
  return 1
fi
primary=NoPrimary
primaryconf=$1$2
njobs=$3
eventsperjob=$4
#
# now generate the fcl
#
generate_fcl --dsconf=${primaryconf} --dsowner=mu2e --run-number=1202 --description=${primary} --events-per-job=${eventsperjob} --njobs=${njobs} \
  --include Production/JobConfig/primary/${primary}.fcl
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf ${primary}\_$dirname
  mv $dirname ${primary}\_$dirname
 fi
done


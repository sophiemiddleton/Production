generate_fcl --dsconf=MDC2020$1 --dsowner=mu2e --description=MuonStopSelector --include Production/JobConfig/beam/MuonStopSelector.fcl \
--inputs TargetStops$1.txt --merge-factor 1000
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf MuonStops$1_$dirname
  mv $dirname MuonStops$1_$dirname
 fi
done


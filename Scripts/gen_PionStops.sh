generate_fcl --dsconf=v0 --dsowner=sophie --description=PionStopSelector --include Production/JobConfig/pileup/PionStopSelector.fcl \
--inputs PiTargetStops.txt --merge-factor 1000
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf PionStops$1_$dirname
  mv $dirname PionStops$1_$dirname
 fi
done

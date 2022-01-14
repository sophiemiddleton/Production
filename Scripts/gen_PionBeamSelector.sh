generate_fcl --dsconf=MDC2020$1 --dsowner=sophie --description=PionBeamSelector --include JobConfig/beam/PionBeamSelector.fcl \
--inputs PiInfiniteBeamv2.txt --merge-factor 1000
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf PionBeamSelector$1_$dirname
  mv $dirname PionBeamSelector$1_$dirname
 fi
done


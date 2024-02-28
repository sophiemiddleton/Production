generate_fcl --dsconf=MDC2020$1 --dsowner=mu2e --description=BeamSplitter --include Production/JobConfig/beam/BeamSplitter.fcl \
--inputs Beam$1.txt --merge-factor 1000
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf BeamSpliter$1_$dirname
  mv $dirname BeamSpliter$1_$dirname
 fi
done


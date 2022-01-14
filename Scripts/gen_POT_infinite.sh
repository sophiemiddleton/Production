generate_fcl --dsconf=MDC2020$1 --dsowner=sophie --run-number=1201 --events-per-job=2000 --njobs=1000 --include JobConfig/beam/POT_infinitepion.fcl --description=POT_infinite
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf POT_infinite$1_$dirname
  mv $dirname POT_infinite$1_$dirname
 fi
done


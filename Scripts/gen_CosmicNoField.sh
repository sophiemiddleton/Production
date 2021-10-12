generate_fcl --dsconf=MDC2020$1 --dsowner=brownd --run-number=1205 --description=CosmicNoField --events-per-job=80000 --njobs=48 --include JobConfig/cosmic/S2ResamplerNoField.fcl --auxinput=1:physics.filters.cosmicResample.fileNames:CosmicS1$1.txt
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf CosmicNoField$1_$dirname
  mv $dirname CosmicNoField$1_$dirname
 fi
done


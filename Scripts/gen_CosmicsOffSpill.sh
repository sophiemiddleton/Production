generate_fcl --dsconf=MDC2020d --dsowner=brownd --override-outputs --auto-description=OffSpill --include JobConfig/digitize/OffSpill.fcl \
--inputs=Cosmics$1.txt --merge-factor=1
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf CosmicsOffSpill$1_$dirname
  mv $dirname CosmicsOffSpill$1_$dirname
 fi
done


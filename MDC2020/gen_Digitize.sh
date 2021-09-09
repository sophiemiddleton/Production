generate_fcl --dsconf="MDC2020$2" --dsowner=brownd --auto-description=Digi --include JobConfig/digitize/OnSpill.fcl \
--inputs "$1$2.txt" --merge-factor=1
for dirname in 000 001 002 003 004 005 006 007 008 009; do
 if test -d $dirname; then
  echo "found dir $dirname"
  rm -rf "$1Digi_$dirname"
  mv $dirname "$1Digi_$dirname"
 fi
done


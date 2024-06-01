FF=dts.mu2e.ensemble-1BB-CEDIOCRYCosmic-600000s-p95MeVc.MDC2024.001201_00000000.art
nsplit=10

fn=$(basename $FF)
fn0=$(echo $fn | awk -F. '{print $1"."$2"."$3"."$4"."$5 }' )
fn1=$(echo $fn | awk -F. '{print $6 }' )

ntot=$(count_events $FF | head -1 | awk '{print $4}')
stride=$((ntot/nsplit))
i=0
while [ $i -lt $nsplit ];
do
    skip=$((stride*i))
    ofn=$( printf "%s-%02d.%s" $fn0 $i $fn1)
    #make sure the last split gets the last event by running to the end
    nevtsf="--nevts $stride"
    [ $((i+1)) -eq $nsplit ] && nevtsf=""
    echo "split $i starts at $skip"
    mu2e --nskip $skip $nevtsf -o $ofn -c Production/JobConfig/common/artcat.fcl $FF
    i=$((i+1))
done

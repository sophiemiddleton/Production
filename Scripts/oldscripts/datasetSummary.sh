#!/bin/bash
#
#  Summarize contents of a production dataset
# $1 = production (ie MDC2020k)
# $2 = user (default mu2epro)
user="mu2epro"
if [[ ! -z $2 ]]; then
  echo supplied user
  user=$2
fi
# you must have run 'setup sam_web_client' (or 'setup dhtools') before running this script
#
samweb list-definitions --user=$user | grep $1 | grep art > Datasets.txt
#
echo "                        dataset                                    N ev  N files  totGB  MB/file  ev/file"
echo "---------------------------------------------------------------------------------------------------------"
while read DS || [[ -n $DS ]]; do
  TMP=`mktemp`
  samweb list-files --summary "dh.dataset=$DS and availability:anylocation" > $TMP
  NN=`cat $TMP | grep File | awk '{print $3}'`
  if [ $NN -gt 0 ]; then
    SZ=`cat $TMP | grep Total | awk '{printf "%d",$3/1000000000.0}'`
    SZF=`cat $TMP | grep Total | awk '{printf "%d",$3/1000000.0/'$NN'}'`
    EC=`cat $TMP | grep Event | awk '{printf "%d",$3}'`
    ECF=`cat $TMP | grep Event | awk '{printf "%d",$3/'$NN'}'`
    printf "%60s  %9d  %5d  %5d  %5d  %7d\n" $DS $EC $NN $SZ $SZF $ECF
  else
    printf "%60s  %5d  \n" $DS $NN
  fi
  rm -f $TMP
done < Datasets.txt

#rm Datasets.txt

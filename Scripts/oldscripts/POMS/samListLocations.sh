#!/bin/bash
OLDIFS=${IFS}
samweb list-file-locations "${@}" | while read line 
do
   IFS=$'\t'
   read -a strarr <<< "$line"
   FILEPATH=`echo ${strarr[0]} | cut -d':' -f2`
   echo "${FILEPATH}/${strarr[1]}"
done
IFS=${OLDIFS}

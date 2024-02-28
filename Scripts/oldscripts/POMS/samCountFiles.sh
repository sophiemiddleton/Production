#!/bin/bash
#echo ${@}
samweb list-files --summary "dh.dataset=${@}" | while read line
do
  read -a strarr <<< "$line"
#  echo ${strarr[0]} ${strarr[1]} 
  if [[ "${strarr[0]}" =~ "File" ]]; then
    echo "${strarr[2]}"
  fi
done

FILE=$1
for i in $(eval echo {1..$2})
    do cat $1 | shuf >> ${FILE%%.*}_cat.txt
done

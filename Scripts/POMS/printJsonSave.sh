if [ -f parents.txt ]; then
    printJson ${1} --parents=parents.txt > ${1}.json
else
    printJson ${1} --no-parents > ${1}.json
fi
sed -i 's/, "md5.*"//' ${1}.json
cat ${1}.json

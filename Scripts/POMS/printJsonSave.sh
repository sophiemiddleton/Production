if [ -f parents.txt ]; then
    printJson.sh --parents parents.txt ${1} > ${1}.json
else
    printJson.sh --no-parents ${1} > ${1}.json
fi
sed -i 's/, "md5.*"//' ${1}.json
cat ${1}.json

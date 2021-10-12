#!/bin/bash
FILENAME=`grep "source.fileNames " $2 -A 1 | awk -F'"' '{print $2}' | tr -d '\n'`
SEED=`grep baseSeed $2`
SEED=${SEED//services.SeedService.baseSeed: }
echo $SEED > seed.txt
echo $FILENAME > filename.txt
echo $2 > torun.txt

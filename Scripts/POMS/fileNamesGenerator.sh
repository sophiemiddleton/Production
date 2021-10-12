#!/bin/bash

for i in $(eval echo {1..$2});
  do echo "sim.$3.corsika.v1.$[$i+$1].csk";
done

#!/usr/bin/bash
#Create and index definition. The scripted is sourced by scripts that generate cnf*tar file.

samweb create-definition idx_${index_dataset} "dh.dataset etc.mu2e.index.000.txt and dh.sequencer < ${idx_format}"
echo "Created definiton: idx_${index_dataset}"
samweb describe-definition idx_${index_dataset}
ls -ltr

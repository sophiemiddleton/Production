#!/bin/bash

mkdir /pnfs/mu2e/persistent/datasets/phy-etc/etc/mu2e/index/001/txt/
for i in {0..9}
do
  $filename = /pnfs/mu2e/persistent/datasets/phy-etc/etc/mu2e/index/001/txt/etc.mu2e.index.001.000000$i.txt
  touch $filename
  echo "adding filename: "  etc.mu2e.index.001.000000$i.txt
  samweb declare-file   etc.mu2e.index.001.000000$i.txt root://fndca1.fnal.gov:1094/pnfs/fnal.gov/usr/mu2e/persistent/datasets/phy-etc/etc/mu2e/index/001/txt/
done

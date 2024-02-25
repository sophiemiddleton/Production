# Introduction

This set of scripts is built to allow construction of "fake data-sets."

# Scripts

Since MDC2018 we have made huge progress in consolodating our scripts and as part of our MDC2020 effort we now have a set of multi-purpose scripts.

## python scripts

In the current generation of these scripts we require just two python scripts to mix our input DTS level primary files. The resulting "mixed" DTS sample should have a correctly normalized set of DTS events which can then be passed through the subsequent steps of the Production chain which result in a normalized reconstructed data sample of the given livetime input into the run_si.py script.

The most important thing to remember is to ensure that the livetime/POT are not going to result in more expected events from any process than is available in the input DTS files for that primary. This will result in a failure mode.

Also note that no trigger is applied to the DTS events, this will be applied in the digitization stage which follows ensembling.

### normalizations.py

This script is important. It calculates the normalization factors for each process. You can test it interactively by running it on command line. Livetime should be in hours.

### run_si.py

Runs "SI" which is SamplingInput. This is the script which is run last of all and makes the ensemble samples. It takes two arguments: an input directory and an output directory. The input config directory is required to have the following files

* livetime - one line containing livetime in seconds
* rue/rup/kmax - one line containing value
* settings:
     - dem generation min energy
     - dep generation max energy
     - tmin used for RPC generation
     - max livetime (???)
     - run number
     - seed for sampling input
* filenames_\<sample name\> - one filename per line

The script will then call normalizations.py to calculate expected number of events per input type, and the total number of events in the ensemble. It will then iteratively create and run SamplingInput.fcl jobs, keeping track of which events in which files have been used, until the full ensemble is generated.

run_si.py is then ran on the command line in the following way: 

```
run_si.py <path to config directory> <path to output directory>
```

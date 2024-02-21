# Introduction

This set of scripts is built to allow construction of "fake data-sets."

# Scripts

Since MDC2018 we have made huge progress in consolodating our scripts and as part of our MDC2020 effort we now have a set of multi-purpose scripts.

## python scripts

### normalizations.py

This script is important. It calculates the normalization factors for each process.

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

## gen_Primary.sh

The first stage in the process is to run gen_Primary for a sufficient number of events. We will start with CE, DIO and cosmics.

Cosmics follow a separate stream and to some extent limit the amount of "data" we can make.

The number of events for each background must be greater than what we need for all our samples. So minimum number of events comes from our normalization. We will run samples for a selection of live-times but again we will need to understand how cosmic simulations limit this.

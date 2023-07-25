# Introduction

This set of scripts is built to allow construction of "fake data-sets."

# Scripts

Since MDC2018 we have made huge progress in consolodating our scripts and as part of our MDC2020 effort we now have a set of multi-purpose scripts.

## python scripts

### normalizations.py

This script is important. It calculates the normalization factors for each process.

### run_si.py

Runs "SI" which is SamplingInput. This is the script which is run last of all and makes the ensemble samples.

### generateEnsemble.py

This script makes .sh for given backgrounds ensuring enough events. We might want to just do this our selves since we now have all we need in POMs.

### generateEnsembleFcl.py

Think this is taken care of too.

## gen_Primary.sh

The first stage in the process is to run gen_Primary for a sufficient number of events. We will start with CE, DIO and cosmics.

Cosmics follow a separate stream and to some extent limit the amount of "data" we can make.

The number of events for each background must be greater than what we need for all our samples. So minimum number of events comes from our normalization. We will run samples for a selection of live-times but again we will need to understand how cosmic simulations limit this.

## gen_Mix.sh


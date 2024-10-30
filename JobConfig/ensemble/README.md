# Introduction

This set of scripts is built to allow construction of "fake data-sets."

# Infrastructure

Within this directory are several sub-dirs:

* python
* scripts

## python scripts

In the current generation of these scripts we require just two python scripts to mix our input DTS level primary files. The resulting "mixed" DTS sample should have a correctly normalized set of DTS events which can then be passed through the subsequent steps of the Production chain which result in a normalized reconstructed data sample of the given livetime input into the run_si.py script.

The most important thing to remember is to ensure that the livetime/POT are not going to result in more expected events from any process than is available in the input DTS files for that primary. This will result in a failure mode.

Also note that no trigger is applied to the DTS events, this will be applied in the digitization stage which follows ensembling.

### normalizations.py

This script is important. It calculates the normalization factors for each process. You can test it interactively by running it on command line. Livetime should be in hours.

### make_template_fcl.py

Runs "SI" which is SamplingInput. This is the script which is run last of all and makes the ensemble samples. It takes two arguments: 

* livetime (in seconds)
* BB (booster batch mode)
* rue (Rmue chosen)
* dem_emin (min energy for DIO)
* prc (list of process being input)
* tmin (time min cut)

The script will then call normalizations.py to calculate expected number of events per input type, and the total number of events in the ensemble. It will then iteratively create and run SamplingInput.fcl jobs, keeping track of which events in which files have been used, until the full ensemble is generated.

## Script Workflow:

Two .sh scripts are provided to streamline the ensembling process.

The workflow proceeds in two stages:

1) Stage 1: Make the input files, to get the stats needed for the input files (DIO, CE, RPC etc.) run the Stage 1 script. Then build the input campaigns using POMS.
2) Stage 2: Once all input samples are ready run Stage 2, pass as input the config.txt made by Stage 1.

### Stage 1: Make Inputs

This script is to calculate how many of each process to generate. It uses the cosmics as the "standard". There is also a .txt. file output with the details of the chosen input parameters. 

We choose the Cosmic jobs to be the "standard" since we do not expect to remake them too frequently.

The Stage1 .sh takes input in the form of a set of cosmic files, calculates livetime and the number of expected other events for the same livetime, assuming a given BB mode.

From the cosmics list, it assesses the livetime and then calculates how many other events would arrive in the same time for the chosen beam conditions.

The output is a text file which lists, number of final jobs needed (of course you can have more than this, but you will need to Cat the files). The file also lists total events for each input.

The .txt is read into Stage2.

#### To make the input processes

You will need to run each process separately, using the number of jobs and events from the previous script. Base the number of jobs and events-per-job on the output from S1.

### Stage 2: Running on the Ensembling on the Grid

Stage 2 takes the config made in S1 as input as well as a chosen tag for your data set. The script will submit the job to the grid.

To make the template fcl file, first run genEnsemble.sh. The arguments are as follows:

```
Stage2_makeensemble.sh --tag MDS1a
```

This will output a .tar file. This can be submitted to the grid as follows:

```
mu2ejobsub --jobdef cnf.sophie.ensembleMDS1a.MDC2020aj.0.tar --firstjob=0 --njobs=10  --default-protocol ifdh --default-location tape
```

This is done within the script.

### POMs

The above command can be run interactively for personal submissions. I am working on the POMs scripts.

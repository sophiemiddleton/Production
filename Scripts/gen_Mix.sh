#!/usr/bin/bash
#
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
# $1 is the name of the primary (ie CeEndpoint, etc).
# $2 is the dataset description
# $3 is the campaign version of the input file.
# $4 is the campaign version of the output and primary file.
# $5 is the number of events per job. 
# $6 is the number of jobs.

if [[ $# -eq 0 ]] ; then
    usage='Usage:
gen_Mix.sh [primaryName] [datasetDescription] [campaignInput] \
           [campaignOutput] [nEventsPerJob] [nJobs]

This script will produce the fcl files needed for a mixing stage. It
is necessary to provide, in order:
- the name of the primary [primaryName]
- the dataset description [datasetDescription],
- the campaign version of the input file [campaignInput],
- the campaign version of the output file [campaignOutput],
- the number of events per job [nEventsPerJob] (needed only for NoPrimary),
- the number of jobs [nJobs] (needed only for NoPrimary).

Example:
    gen_Mix.sh CeEndpoint MDC2020 k m

This will produce the fcl files for a mixing stage of 100 jobs with 1000 events
per job, using the CeEndpoint primary and the MDC2020k samples as input. The output
files will have the MDC2020m description.'
    echo "$usage"
    exit 0
fi

eventsperjob=$5
njobs=$6
# create the mixin input lists
samweb list-file-locations --schema=root --defname="dts.mu2e.MuBeamFlashCat.$2$3.art"  | cut -f1 > MuBeamFlashCat$3.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.EleBeamFlashCat.$2$3.art"  | cut -f1 > EleBeamFlashCat$3.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.NeutralsFlashCat.$2$3.art"  | cut -f1 > NeutralsFlashCat$3.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.MuStopPileupCat.$2$3.art"  | cut -f1 > MuStopPileupCat$3.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh "dts.mu2e.MuBeamFlashCat.$2$3.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuBeamFlashCat.$2$3.art"`
let nskip_MuBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.EleBeamFlashCat.$2$3.art"`
nevts=`samCountEvents.sh "dts.mu2e.EleBeamFlashCat.$2$3.art"`
let nskip_EleBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.NeutralsFlashCat.$2$3.art"`
nevts=`samCountEvents.sh "dts.mu2e.NeutralsFlashCat.$2$3.art"`
let nskip_NeutralsFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.MuStopPileupCat.$2$3.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuStopPileupCat.$2$3.art"`
let nskip_MuStopPileup=nevts/nfiles
#
# write the template fcl
#
rm template.fcl
#
# I have to deep-copy the main file so I can later edit the outputs
if [ $1 == "NoPrimary" ]; then
  echo '#include "Production/JobConfig/mixing/NoPrimary.fcl"' >> template.fcl
# the following should be an option (or gotten through the database)
  echo '#include "Production/JobConfig/mixing/OneBB.fcl"' >> template.fcl
elif [ $1 == "NoPrimaryPBISequence" ]; then
  samweb list-file-locations --schema=root --defname="sim.mu2e.$1.$2$4.art"  | cut -f1 > $1$4.txt
  echo '#include "Production/JobConfig/mixing/NoPrimaryPBISequence.fcl"' >> template.fcl
else
  samweb list-file-locations --schema=root --defname="dts.mu2e.$1.$2$4.art"  | cut -f1 > $1$4.txt
  echo '#include "Production/JobConfig/mixing/Mix.fcl"' >> template.fcl
  echo '#include "Production/JobConfig/mixing/OneBB.fcl"' >> template.fcl  # number of booster batchs should be configuratble FIXME!
fi
#
# set the skips
#
echo physics.filters.MuBeamFlashMixer.mu2e.MaxEventsToSkip: ${nskip_MuBeamFlash} >> template.fcl
echo physics.filters.EleBeamFlashMixer.mu2e.MaxEventsToSkip: ${nskip_EleBeamFlash} >> template.fcl
echo physics.filters.NeutralsFlashMixer.mu2e.MaxEventsToSkip: ${nskip_NeutralsFlash} >> template.fcl
echo physics.filters.MuStopPileupMixer.mu2e.MaxEventsToSkip: ${nskip_MuStopPileup} >> template.fcl
#
# setup database access for SimEfficiencies
#
echo services.DbService.purpose: $2$3 >> template.fcl
#
# overwrite the outputs
#
echo outputs.TriggeredOutput.fileName: \"dig.owner.${1}MixTriggered.version.sequencer.art\" >> template.fcl
echo outputs.UntriggeredOutput.fileName: \"dig.owner.${1}MixUntriggered.version.sequencer.art\" >> template.fcl
#
# run generate_fcl
#
if [ $1 == "NoPrimary" ]; then
  generate_fcl --dsconf="$2$4" --dsowner=mu2e --description="$1Mix" --embed template.fcl \
  --run-number=1203 --events-per-job=$eventsperjob --njobs=$njobs \
  --auxinput=1:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat$3.txt \
  --auxinput=1:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat$3.txt \
  --auxinput=1:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat$3.txt \
  --auxinput=1:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat$3.txt
else
  generate_fcl --dsconf="$2$4" --dsowner=mu2e --description="$1Mix" --embed template.fcl \
  --inputs="$1$4.txt" --merge-factor=1 \
  --auxinput=1:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat$3.txt \
  --auxinput=1:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat$3.txt \
  --auxinput=1:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat$3.txt \
  --auxinput=1:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat$3.txt
fi

# This is commented out because it's not needed with POMS. Uncomment if running it
# standalone

# for dirname in 000 001 002 003 004 005 006 007 008 009; do
#  if test -d $dirname; then
#   echo "found dir $dirname"
#   rm -rf "$1Mix_$dirname"
#   mv $dirname "$1Mix_$dirname"
#  fi
# done


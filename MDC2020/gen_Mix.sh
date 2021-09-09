#!/usr/bin/bash
#
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
# $1 is the name of the primary (ie CeEndpoint, etc). $2 is the campaign version
# $3 is the number of events per job. $4 is the number of jobs.
eventsperjob=$3
njobs=$4
# create the mixin input lists
samListLocations --defname="dts.mu2e.MuBeamFlashCat.MDC2020$2.art" > MuBeamFlashCat$2.txt
samListLocations --defname="dts.mu2e.EleBeamFlashCat.MDC2020$2.art" > EleBeamFlashCat$2.txt
samListLocations --defname="dts.mu2e.NeutralsFlashCat.MDC2020$2.art" > NeutralsFlashCat$2.txt
samListLocations --defname="dts.mu2e.MuStopPileupCat.MDC2020$2.art" > MuStopPileupCat$2.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh "dts.mu2e.MuBeamFlashCat.MDC2020$2.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuBeamFlashCat.MDC2020$2.art"`
let nskip_MuBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.EleBeamFlashCat.MDC2020$2.art"`
nevts=`samCountEvents.sh "dts.mu2e.EleBeamFlashCat.MDC2020$2.art"`
let nskip_EleBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.NeutralsFlashCat.MDC2020$2.art"`
nevts=`samCountEvents.sh "dts.mu2e.NeutralsFlashCat.MDC2020$2.art"`
let nskip_NeutralsFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.MuStopPileupCat.MDC2020$2.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuStopPileupCat.MDC2020$2.art"`
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
  echo '#include "Production/JobConfig/mixing/NoPrimaryPBISequence.fcl"' >> template.fcl
else
  echo '#include "Production/JobConfig/mixing/Mix.fcl"' >> template.fcl
  echo '#include "Production/JobConfig/mixing/OneBB.fcl"' >> template.fcl
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
echo 'services.ProditionsService.simbookkeeper.useDb: true' >> template.fcl
echo services.DbService.purpose: MDC2020$2 >> template.fcl
#
# overwrite the outputs
#
echo outputs.TriggeredOutput.fileName: \"dig.owner.${1}MixTriggered.version.sequencer.art\" >> template.fcl
echo outputs.UntriggeredOutput.fileName: \"dig.owner.${1}MixUntriggered.version.sequencer.art\" >> template.fcl
#
# run generate_fcl
#
if [ $1 == "NoPrimary" ]; then
  generate_fcl --dsconf="MDC2020$2" --dsowner=mu2e --description="$1Mix" --embed template.fcl \
  --run-number=1203 --events-per-job=$eventsperjob --njobs=$njobs \
  --auxinput=1:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat$2.txt \
  --auxinput=1:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat$2.txt \
  --auxinput=1:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat$2.txt \
  --auxinput=1:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat$2.txt
else
  generate_fcl --dsconf="MDC2020$2" --dsowner=mu2e --description="$1Mix" --embed template.fcl \
  --inputs="$1$2.txt" --merge-factor=1 \
  --auxinput=1:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat$2.txt \
  --auxinput=1:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat$2.txt \
  --auxinput=1:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat$2.txt \
  --auxinput=1:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat$2.txt
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


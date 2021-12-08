#!/usr/bin/bash
#
# create fcl to produced mixed digis
# this script requires mu2etools, mu2efiletools and dhtools be setup
# It also requires the SimEfficiencies for the beam campaign be entered in the database
# $1 is the name of the primary (ie CeEndpoint, etc).
# $2 is the dataset description
# $3 is the campaign version of the mixin files.
# $4 is the campaign version of the primary files.
# $5 is the campaign version of the output files.
# $6 is the database version
# $7 is the number of booster batches

# optional arguments:
# $8 is the number of events per job (only needed for NoPrimary, ignored otherwise)
# $9 is the number of jobs (only needed for NoPrimary, ignored otherwise)
# $10 is a flag : if not null, directories are renamed

usage() { echo "Usage:
  source Production/Scripts/gen_Mix.sh [primaryName] [datasetDescription] [mixin version] \
    [primary version] [output version] [database version] [nBoosterBatches]

  This script will produce the fcl files needed for a mixing stage. You must provide in order:
  - the name of the primary [primaryName]
  - the dataset description [datasetDescription],
  - the campaign version of the input file [campaignInput],
  - the campaign version of the primary file [primaryVersion],
  - the campaign version of the output file [campaignOutput],
  - the database version
  - the number of booster batches (one or two)
  Example:
  gen_Mix.sh CeEndpoint MDC2020 k m m v2_0 one
  This will produce the fcl files for a mixing stage
  using the MDC2020m CeEndpoint primary as input and the MDC2020k pileup as mixins.
  The output files will have the MDC2020m description."
}

if [[ $# -lt 7 ]] ; then
  usage
  return 1
fi

primary=$1
mixinconf=$2$3
primaryconf=$2$4
outconf=$2$5
mixout=${primary}Mix
dbver=$6
nbb=$7
eventsperjob=-1
njobs=-1
moveit=
if [[ $# -ge 8 ]]; then eventsperjob=$8; fi
if [[ $# -ge 9 ]]; then  njobs=$9; fi
if [[ $# -ge 10 ]]; then  moveit=$10; fi
echo "Generating mixing scripts for $primary conf $primaryconf mixin conf $mixinconf output conf $outconf database version $dbver with $nbb booster batches"

# create the mixin input lists
samweb list-file-locations --schema=root --defname="dts.mu2e.MuBeamFlashCat.$mixinconf.art"  | cut -f1 > MuBeamFlashCat$mixinconf.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.EleBeamFlashCat.$mixinconf.art"  | cut -f1 > EleBeamFlashCat$mixinconf.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.NeutralsFlashCat.$mixinconf.art"  | cut -f1 > NeutralsFlashCat$mixinconf.txt
samweb list-file-locations --schema=root --defname="dts.mu2e.MuStopPileupCat.$mixinconf.art"  | cut -f1 > MuStopPileupCat$mixinconf.txt
# calucate the max skip from the dataset
nfiles=`samCountFiles.sh "dts.mu2e.MuBeamFlashCat.$mixinconf.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuBeamFlashCat.$mixinconf.art"`
let nskip_MuBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.EleBeamFlashCat.$mixinconf.art"`
nevts=`samCountEvents.sh "dts.mu2e.EleBeamFlashCat.$mixinconf.art"`
let nskip_EleBeamFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.NeutralsFlashCat.$mixinconf.art"`
nevts=`samCountEvents.sh "dts.mu2e.NeutralsFlashCat.$mixinconf.art"`
let nskip_NeutralsFlash=nevts/nfiles
nfiles=`samCountFiles.sh "dts.mu2e.MuStopPileupCat.$mixinconf.art"`
nevts=`samCountEvents.sh "dts.mu2e.MuStopPileupCat.$mixinconf.art"`
let nskip_MuStopPileup=nevts/nfiles
#
# write the mix.fcl
#
rm mix.fcl
#
# create a template file.  Start with the primary
#
if [ $primary == "NoPrimary" ]; then
  echo '#include "Production/JobConfig/mixing/NoPrimary.fcl"' >> mix.fcl
  if [[ $njobs -lt 0 || $eventsperjob -lt 0 ]]; then
    echo njobs and eventsperjob must be specified for NoPrimary
    return 0;
  fi
elif [[ $primary == PBI* ]]; then
  samweb list-file-locations --schema=root --defname="sim.mu2e.${primary}.${primaryconf}.art"  | cut -f1 > ${primary}.txt
  echo '#include "Production/JobConfig/mixing/NoPrimaryPBISequence.fcl"' >> mix.fcl
else
  samweb list-file-locations --schema=root --defname="dts.mu2e.${primary}.${primaryconf}.art"  | cut -f1 > ${primary}.txt
  echo '#include "Production/JobConfig/mixing/Mix.fcl"' >> mix.fcl
fi
# setup the number of booster batches
if [ $nbb == "one" ]; then
  echo '#include "Production/JobConfig/mixing/OneBB.fcl"' >> mix.fcl
elif [ $nbb == "two" ]; then
  echo '#include "Production/JobConfig/mixing/TwoBB.fcl"' >> mix.fcl
else
  echo "Must specify 'one' or 'two' booster batches"
fi
#
# set the skips
#
echo physics.filters.MuBeamFlashMixer.mu2e.MaxEventsToSkip: ${nskip_MuBeamFlash} >> mix.fcl
echo physics.filters.EleBeamFlashMixer.mu2e.MaxEventsToSkip: ${nskip_EleBeamFlash} >> mix.fcl
echo physics.filters.NeutralsFlashMixer.mu2e.MaxEventsToSkip: ${nskip_NeutralsFlash} >> mix.fcl
echo physics.filters.MuStopPileupMixer.mu2e.MaxEventsToSkip: ${nskip_MuStopPileup} >> mix.fcl
#
# setup database access for SimEfficiencies
#
echo services.DbService.purpose: $outconf >> mix.fcl
echo services.DbService.version: $dbver >> mix.fcl
#
# overwrite the outputs
#
echo outputs.TriggeredOutput.fileName: \"dig.owner.${mixout}Triggered.version.sequencer.art\" >> mix.fcl
echo outputs.UntriggeredOutput.fileName: \"dig.owner.${mixout}Untriggered.version.sequencer.art\" >> mix.fcl
#
# run generate_fcl
#
if [ $1 == "NoPrimary" ]; then
  generate_fcl --dsconf="$outconf" --dsowner=mu2e --description="$mixout" --embed mix.fcl \
  --run-number=1203 --events-per-job=$eventsperjob --njobs=$njobs \
  --auxinput=1:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat$mixinconf.txt \
  --auxinput=25:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat$mixinconf.txt \
  --auxinput=1:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat$mixinconf.txt \
  --auxinput=25:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat$mixinconf.txt
else
  generate_fcl --dsconf="$outconf" --dsowner=mu2e --description="$mixout" --embed mix.fcl \
  --inputs="$primary.txt" --merge-factor=1 \
  --auxinput=1:physics.filters.MuStopPileupMixer.fileNames:MuStopPileupCat$mixinconf.txt \
  --auxinput=25:physics.filters.EleBeamFlashMixer.fileNames:EleBeamFlashCat$mixinconf.txt \
  --auxinput=1:physics.filters.MuBeamFlashMixer.fileNames:MuBeamFlashCat$mixinconf.txt \
  --auxinput=25:physics.filters.NeutralsFlashMixer.fileNames:NeutralsFlashCat$mixinconf.txt
fi

if [ ! -z "$moveit" ]; then
  for dirname in 000 001 002 003 004 005 006 007 008 009; do
    if test -d $dirname; then
      echo "found dir $dirname"
      if test -d ${mixout}_${dirname}; then
        echo "removing ${mixout}_${dirname}"
        rm -rf "${mixout}_${dirname}"
      fi
      echo "moving $dirname to ${mixout}_${dirname}"
      mv $dirname $mixout\_$dirname
    fi
  done
fi


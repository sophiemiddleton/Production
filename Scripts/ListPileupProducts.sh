#!/usr/bin/bash
#
#  This script dumps the output list to a text file for validation and verification
#  It can either run on the output of an official production, or by running the tree of Production/JobConfig/beam jobs (with minimal statistics).
#  Execute from a valid Mu2e muse workdir after 'muse setup' and 'dhtools setup' and 'vomsCert'
#  Original author: Dave Brown (LBNL)
#
if [[ ${2} == "" ]]; then
   echo "Getting beam products from Production version $1"
  # locate the specified output
  samweb list-file-locations --schema=root --defname="sim.mu2e.EleBeamCat.$1.art"  | cut -f1 > EleBeam.txt
  samweb list-file-locations --schema=root --defname="sim.mu2e.MuBeamCat.$1.art"  | cut -f1 > MuBeam.txt
  samweb list-file-locations --schema=root --defname="sim.mu2e.NeutralsCat.$1.art"  | cut -f1 > Neutrals.txt
  samweb list-file-locations --schema=root --defname="sim.mu2e.TargetStopsCat.$1.art"  | cut -f1 > TargetStops.txt
  # create scripts for running changed and neutral resampling off these outputs.  These need the resampler inputs
  rm mubeamresample.fcl
  rm elebeamresample.fcl
  rm neutresample.fcl
  rm tgtresample.fcl
  echo '#include "Production/JobConfig/pileup/MuBeamResampler.fcl"' >> mubeamresample.fcl
  echo 'source.firstRun: 1202' >> mubeamresample.fcl
  echo 'source.firstSubRun: 0' >> mubeamresample.fcl
  echo 'source.maxEvents: 1000' >> mubeamresample.fcl
  echo 'services.SeedService.baseSeed: 502016040' >> mubeamresample.fcl
  echo 'physics.filters.beamResampler.mu2e.MaxEventsToSkip: 0' >> mubeamresample.fcl
  echo 'physics.filters.TargetStopPrescaleFilter.nPrescale : 1' >> mubeamresample.fcl
  echo 'physics.filters.EarlyPrescaleFilter.nPrescale : 100' >> mubeamresample.fcl
  echo 'physics.filters.beamResampler.fileNames : [' >> mubeamresample.fcl
  echo "\"`cat MuBeam.txt`\"" >> mubeamresample.fcl
  echo ']' >> mubeamresample.fcl

  echo '#include "Production/JobConfig/pileup/EleBeamResampler.fcl"' >> elebeamresample.fcl
  echo 'source.firstRun: 1202' >> elebeamresample.fcl
  echo 'source.firstSubRun: 0' >> elebeamresample.fcl
  echo 'source.maxEvents: 10000' >> elebeamresample.fcl
  echo 'services.SeedService.baseSeed: 502016040' >> elebeamresample.fcl
  echo 'physics.filters.beamResampler.mu2e.MaxEventsToSkip: 0' >> elebeamresample.fcl
  echo 'physics.filters.EarlyPrescaleFilter.nPrescale : 100' >> elebeamresample.fcl
  echo 'physics.filters.beamResampler.fileNames : [' >> elebeamresample.fcl
  echo "\"`cat EleBeam.txt`\"" >> elebeamresample.fcl
  echo ']' >> elebeamresample.fcl

  echo '#include "Production/JobConfig/pileup/NeutralsResampler.fcl"' >> neutresample.fcl
  echo 'source.firstRun: 1202' >> neutresample.fcl
  echo 'source.firstSubRun: 0' >> neutresample.fcl
  echo 'source.maxEvents: 10000' >> neutresample.fcl
  echo 'services.SeedService.baseSeed: 502016040' >> neutresample.fcl
  echo 'physics.filters.neutralsResampler.mu2e.MaxEventsToSkip: 0' >> neutresample.fcl
  echo 'physics.filters.TargetStopPrescaleFilter.nPrescale : 1' >> neutresample.fcl
  echo 'physics.filters.EarlyPrescaleFilter.nPrescale : 1' >> neutresample.fcl
  echo 'physics.filters.neutralsResampler.fileNames : [' >> neutresample.fcl
  echo "\"`cat Neutrals.txt`\"" >> neutresample.fcl
  echo ']' >> neutresample.fcl

  echo '#include "Production/JobConfig/pileup/MuStopPileup.fcl"' >> tgtresample.fcl
  echo 'source.firstRun: 1202' >> tgtresample.fcl
  echo 'source.firstSubRun: 0' >> tgtresample.fcl
  echo 'source.maxEvents: 10000' >> tgtresample.fcl
  echo 'services.SeedService.baseSeed: 502016040' >> tgtresample.fcl
  echo 'physics.filters.TargetStopResampler.mu2e.MaxEventsToSkip: 0' >> tgtresample.fcl
  echo 'physics.filters.TargetStopResampler.fileNames : [' >> tgtresample.fcl
  echo "\"`cat TargetStops.txt`\"" >> tgtresample.fcl
  echo ']' >> tgtresample.fcl

  # run a small number of these jobs: TODO
  return 0

else
  echo "Dumping products from Production version $1"
  # locate the specified output
  samweb list-file-locations --schema=root --defname="sim.mu2e.TargetStopsCat.$1.art"  | cut -f1 > TargetStops.txt
  samweb list-file-locations --schema=root --defname="sim.mu2e.IPAStopsCat.$1.art"  | cut -f1 > IPAStops.txt
  samweb list-file-locations --schema=root --defname="dts.mu2e.MuBeamFlashCat.$1.art"  | cut -f1 > MuBeamFlash.txt
  samweb list-file-locations --schema=root --defname="dts.mu2e.EleBeamFlashCat.$1.art"  | cut -f1 > EleBeamFlash.txt
  samweb list-file-locations --schema=root --defname="dts.mu2e.NeutralsFlashCat.$1.art"  | cut -f1 > NeutralsFlash.txt
  samweb list-file-locations --schema=root --defname="dts.mu2e.MuStopPileupCat.$1.art"  | cut -f1 > MuStopPileup.txt
fi
# dump the contents of the first events of all the collections
rm TargetStopsProducts$1.txt
rm IPAStopsProducts$1.txt
rm MuBeamFlashProducts$1.txt
rm EleBeamFlashProducts$1.txt
rm NeutralsFlashProducts$1.txt

mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list TargetStops.txt --nevts 1 | grep -E 'MuBeamResampler|PROCESS|PRINCIPAL' > TargetStopsProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list IPAStops.txt --nevts 1 | grep -E 'MuBeamResampler|PROCESS|PRINCIPAL' > IPAStopsProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list MuBeamFlash.txt --nevts 1 | grep -E 'MuBeamResampler|PROCESS|PRINCIPAL' > MuBeamFlashProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list EleBeamFlash.txt --nevts 1 | grep -E 'EleBeamResampler|PROCESS|PRINCIPAL' > EleBeamFlashProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list NeutralsFlash.txt --nevts 1 | grep -E 'NeutralsResampler|PROCESS|PRINCIPAL' > NeutralsFlashProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list MuStopPileup.txt --nevts 1 | grep -E 'MuStopResampler|PROCESS|PRINCIPAL' > MuStopPileupProducts$1.txt


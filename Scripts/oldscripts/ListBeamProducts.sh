#!/usr/bin/bash
#
#  This script dumps the output list to a text file for validation and verification
#  It can either run on the output of an official production, or by running the tree of Production/JobConfig/beam jobs (with minimal statistics).
#  Execute from a valid Mu2e muse workdir after 'muse setup' and 'dhtools setup' and 'vomsCert'
#  Original author: Dave Brown (LBNL)
#
echo $1
if [[ ${1} == "" ]]; then
  echo "Dumping products from current Offline + Production"
  # create a small number of POT
  rm POT.log
#  mu2e -c Production/JobConfig/beam/POT.fcl --nevts 2000 >& POT.log
  # split the beam
  rm BeamSplitter.log
#  mu2e -c Production/JobConfig/beam/BeamSplitter.fcl sim.mu2e.Beam.owner.version.sequencer.art > BeamSplitter.log
#  echo "sim.mu2e.EleBeamCat.owner.version.sequencer.art" >> EleBeam.txt
#  echo "sim.mu2e.MuBeamCat.owner.version.sequencer.art" >> MuBeam.txt
#  echo "sim.mu2e.Neutrals.owner.version.sequencer.art" >> Neutrals.txt
else
  echo "Dumping products from Production version $1"
  # locate the specified output
  samweb list-file-locations --schema=root --defname="sim.mu2e.EleBeamCat.$1.art"  | cut -f1 > EleBeam.txt
  samweb list-file-locations --schema=root --defname="sim.mu2e.MuBeamCat.$1.art"  | cut -f1 > MuBeam.txt
  samweb list-file-locations --schema=root --defname="sim.mu2e.NeutralsCat.$1.art"  | cut -f1 > Neutrals.txt
fi
# dump the contents of the first events of all the collections
rm MuBeamProducts$1.txt
rm EleBeamProducts$1.txt
rm NeutralsProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list MuBeam.txt --nevts 1 | grep -E 'POT|PROCESS|PRINCIPAL' > MuBeamProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list EleBeam.txt --nevts 1 | grep -E 'POT|PROCESS|PRINCIPAL' > EleBeamProducts$1.txt
mu2e -c Offline/Print/fcl/fileDumper.fcl --source-list Neutrals.txt --nevts 1 | grep -E 'POT|PROCESS|PRINCIPAL' > NeutralsProducts$1.txt


#!/usr/bin/bash
# Driver for building a Mock Data Sample (MDS). See README.md in this directory.
#
#   mds.sh <step> --tag <TAG> [options]
#
# Steps, in order (POMS campaigns run between publish/validate and digireco/signal):
#   init      Stage 1  config, livetime, expected yields -> <TAG>/manifest.env
#   build     Stage 2  discover inputs, file lists, template FCL, mu2ejobdef tarball
#   publish   Stage 3  declare + upload tarball and tag-info, write campaign JSON
#   validate  Stage 4  check grid logs against the FCL weights and expected dts yields
#   digireco  Stage 3 --append  write the digi/reco/ntuple stage JSON
#   signal    Stage 5  split signal, make ntuples, build mixed file lists
#   mix       Stage 6  hadd the mixed lists into the final ntuples
#   status    show the manifest, finished steps and SAM file counts
#
# Run 'mds.sh <step> --help' for the options of a step.

NEW_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STEPS="init build publish validate digireco signal mix status"

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

step=${1:-}
case " ${STEPS} " in
  *" ${step} "*) shift; exec "${NEW_DIR}/steps/${step}.sh" "$@" ;;
esac
case "${step}" in
  ""|-h|--help|help) usage; exit 0 ;;
  *) echo "Unknown step '${step}'"; echo ""; usage; exit 1 ;;
esac

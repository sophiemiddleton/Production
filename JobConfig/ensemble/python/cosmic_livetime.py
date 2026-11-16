#!/usr/bin/env python3
"""
Sum the cosmic livetime of a list of CosmicSignal files, with the same
correction for the resampler bug (Mu2e/Offline#1940) that make_template_fcl.py
applies. Used by mds.sh init --compute-livetime.

  cosmic_livetime.py lists/CRYCosmic.chosen
prints
  livetime="<s>"
  cosmic_livetime_correction="subruns corrected N kept M, S1 constants ngen X livetime Y"
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ROOT  # noqa: E402
from make_template_fcl import cosmic_file_livetime, COSMIC_NGEN_S1, COSMIC_LIVETIME_S1  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filelist", help="file with one CosmicSignal file path per line")
    ap.add_argument("--cosmic-ngen", type=float, default=COSMIC_NGEN_S1)
    ap.add_argument("--cosmic-s1-livetime", type=float, default=COSMIC_LIVETIME_S1)
    args = ap.parse_args()

    total, nb, nf = 0., 0, 0
    with open(args.filelist) as f:
        files = [l.strip() for l in f if l.strip()]
    for fn in files:
        fin = ROOT.TFile.Open(fn)
        if not fin or fin.IsZombie():
            sys.exit("cannot open %s" % fn)
        lt, b, k = cosmic_file_livetime(fn, fin.Get("SubRuns"), args.cosmic_ngen, args.cosmic_s1_livetime)
        total += lt
        nb += b
        nf += k
        fin.Close()
    print('livetime="%f"' % total)
    print('cosmic_livetime_correction="%d files, subruns corrected %d kept %d, S1 constants ngen %g livetime %g"'
          % (len(files), nb, nf, args.cosmic_ngen, args.cosmic_s1_livetime))


if __name__ == "__main__":
    main()

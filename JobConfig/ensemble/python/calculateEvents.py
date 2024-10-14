#! /usr/bin/env python
from normalizations import *

def main(args):
    Yield = 0
    if (str(args.printpot) == "print"):
      livetime_to_pot(float(args.livetime), str(args.BB),True)
    if(args.prc == "CEMLL"):
      Yield = ce_normalization(float(args.livetime), float(args.rue), str(args.BB))
      print("CEMLL=",Yield)
    if(args.prc == "DIO"):
      Yield = dio_normalization(float(args.livetime), float(args.dem_emin), str(args.BB))
      print("DIO=",Yield)
    if(args.prc == "CORSIKA"):
      Yield = corsika_onspill_normalization(float(args.livetime), str(args.BB))
      print("CORSIKA=",Yield)
    return (Yield)
    
# for testing only
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--BB", help="BB mode e.g. 1BB")
    parser.add_argument("--livetime", help="simulated livetime")
    parser.add_argument("--rue", help="signal branching rate")
    parser.add_argument("--dem_emin", help="min energy cut")
    parser.add_argument("--prc", help="process")
    parser.add_argument("--printpot", help="print pot", default="no")
    args = parser.parse_args()
    (args) = parser.parse_args()
    main(args)

#! /usr/bin/env python
##from normalizationsOld import *
from normalizations import *

def main(args):
    Yield = 0
    if (str(args.printpot) == "print"):
      getPOT(float(args.livetime), str(args.BB),True)
    if(args.prc == "CEMLL"):
      Yield = ce_normalization(float(args.livetime), float(args.rue), str(args.BB))
      print("CEMLL=",Yield)
    if(args.prc == "DIO"):
      Yield = dio_normalization(float(args.livetime), float(args.dem_emin), str(args.BB))
      print("DIO=",Yield)
    if(args.prc == "CORSIKA"):
      Yield = corsika_onspill_normalization(float(args.livetime), str(args.BB))
      print("CORSIKA=",Yield)
    if(args.prc == "RPC" and int(args.internalrpc) == 1):
      Yield = rpc_normalization(float(args.livetime), str(args.tmin), str(args.internalrpc), str(args.rpcemin), str(args.BB))
      print("InternalRPC=",Yield)
    if(args.prc == "RPC" and int(args.internalrpc) == 0):
      Yield = rpc_normalization(float(args.livetime), str(args.tmin), str(args.internalrpc), str(args.rpcemin)), str(args.BB))
      print("ExternalRPC=",Yield)

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
    parser.add_argument("--tmin", help="tmin", default=0)
    parser.add_argument("--internalrpc", help="internal rpc", default=1)
    args = parser.parse_args()
    (args) = parser.parse_args()
    main(args)

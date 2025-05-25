#! /usr/bin/env python
from normalizations import *

def main(args):
    Yield = 0
    if (str(args.printpot) == "print"):
      getPOT(float(args.livetime), str(args.BB),True)
    if(args.prc == "CeMLeadingLog"):
      Yield = ce_normalization(float(args.livetime), float(args.rue), str(args.BB))
      print(Yield)
    if(args.prc == "GetRMUE"):
      Yield = get_ce_rmue(float(args.livetime), float(args.nsig), str(args.BB))
      print(Yield)
    if(args.prc == "DIO"):
      Yield = dio_normalization(float(args.livetime), float(args.dioemin), str(args.BB))
      print("DIO_yield=",Yield)
    if(args.prc == "CORSIKA"):
      Yield = corsika_onspill_normalization(float(args.livetime), str(args.BB))
      print("CORSIKA_livetime=",Yield)
    if(args.prc == "CRY"):
      Yield = cry_onspill_normalization(float(args.livetime), str(args.BB))
      print("CRY_livetime=",Yield)
    if(args.prc == "RPC" and int(args.internal) == 1):
      Yield = rpc_normalization(float(args.livetime), str(args.tmin), str(args.internal), str(args.rpcemin), str(args.BB))
      print("InternalRPC_yield=",Yield)
    if(args.prc == "RPC" and int(args.internal) == 0):
      Yield = rpc_normalization(float(args.livetime), str(args.tmin), str(args.internal), str(args.rpcemin), str(args.BB))
      print("ExternalRPC_yield=",Yield)
    if(args.prc == "RMC" and int(args.internal) == 1):
      Yield = rmc_normalization(float(args.livetime),  str(args.internal), float(args.rmcemin))
      print("InternalRMC_yield=",Yield)
    if(args.prc == "RMC" and int(args.internal) == 0):
      Yield = rmc_normalization(float(args.livetime),  str(args.internal), float(args.rmcemin))
      print("ExternalRMC_yield=",Yield)
    if(args.prc == "IPAMichel"):
      Yield = ipaMichel_normalization(float(args.livetime), float(args.ipaemin), str(args.BB))
      print("IPAMichel_yield=",Yield)
    return (Yield)
    
# for testing only
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--BB", help="BB mode e.g. 1BB")
    parser.add_argument("--livetime", help="simulated livetime")
    parser.add_argument("--rue", help="signal branching rate")
    parser.add_argument("--dioemin", help="min energy cut dio target")
    parser.add_argument("--ipaemin", help="min energy cut dio ipa")
    parser.add_argument("--rpcemin", help="rpcemin", default=0)
    parser.add_argument("--rmcemin", help="min energy cut rmc")
    parser.add_argument("--prc", help="process")
    parser.add_argument("--printpot", help="print pot", default="no")
    parser.add_argument("--tmin", help="tmin", default=0)
    parser.add_argument("--internal", help="internal", default=1)
    parser.add_argument("--nsig", help="internal")
    args = parser.parse_args()
    (args) = parser.parse_args()
    main(args)

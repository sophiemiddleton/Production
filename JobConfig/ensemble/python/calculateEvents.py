#! /usr/bin/env python
import argparse
from normalizations import *

def main(args):
    # Set verbose mode if requested
    if hasattr(args, 'verbose') and str(args.verbose).lower() in ['true', '1', 'yes']:
        set_verbose(True)
    else:
        set_verbose(False)
    
    # Enable verbose output when printing POT details
    if (str(args.printpot) == "print"):
        set_verbose(True)
    
    Yield = 0
    if (str(args.printpot) == "print"):
      Yield = get_pot(float(args.livetime), str(args.BB), True)
      #print("POT=", Yield)
    if(args.prc == "CeMLeadingLog" or args.prc == "CePLeadingLog"):
      Yield = ce_normalization(float(args.livetime), float(args.rue), str(args.BB))
      print("Ce",Yield)
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
      Yield = rpc_normalization(float(args.livetime), float(args.tmin), str(args.internal), str(args.rpcemin), str(args.BB))
      print("InternalRPC_yield=",Yield)
    if(args.prc == "RPC" and int(args.internal) == 0):
      Yield = rpc_normalization(float(args.livetime), float(args.tmin), str(args.internal), str(args.rpcemin), str(args.BB))
      print("ExternalRPC_yield=",Yield)
    if(args.prc == "RMC" and int(args.internal) == 1):
      Yield = rmc_normalization(float(args.livetime),  str(args.internal), float(args.rmcemin))
      print("InternalRMC_yield=",Yield)
    if(args.prc == "RMC" and int(args.internal) == 0):
      Yield = rmc_normalization(float(args.livetime),  str(args.internal), float(args.rmcemin))
      print("ExternalRMC_yield=",Yield)
    if(args.prc == "RMCN0External"):
      Yield = rmc_0n_normalization(float(args.livetime), float(args.rmcn0emin), internal=0, run_mode=str(args.BB))
      print("ExternalRMCN0_yield=",Yield)
    if(args.prc == "RMCN0Internal"):
      Yield = rmc_0n_normalization(float(args.livetime), float(args.rmcn0emin), internal=1, run_mode=str(args.BB))
      print("InternalRMCN0_yield=",Yield)
    if(args.prc == "RMCPhaseSpace0NExternal"):
      Yield = rmc_0n_normalization(float(args.livetime), float(args.rmcn0emin), internal=0, run_mode=str(args.BB))
      print("ExternalRMCPhaseSpace0N_yield=",Yield)
    if(args.prc == "RMCPhaseSpace0NInternal"):
      Yield = rmc_0n_normalization(float(args.livetime), float(args.rmcn0emin), internal=1, run_mode=str(args.BB))
      print("InternalRMCPhaseSpace0N_yield=",Yield)
    if(args.prc == "RMCN1External"):
      Yield = rmc_1n_normalization(float(args.livetime), float(args.rmcn1emin), internal=0, run_mode=str(args.BB))
      print("ExternalRMCN1_yield=",Yield)
    if(args.prc == "RMCN1Internal"):
      Yield = rmc_1n_normalization(float(args.livetime), float(args.rmcn1emin), internal=1, run_mode=str(args.BB))
      print("InternalRMCN1_yield=",Yield)
    if(args.prc == "RMCPhaseSpace1NExternal"):
      Yield = rmc_1n_normalization(float(args.livetime), float(args.rmcn1emin), internal=0, run_mode=str(args.BB))
      print("ExternalRMCPhaseSpace1N_yield=",Yield)
    if(args.prc == "RMCPhaseSpace1NInternal"):
      Yield = rmc_1n_normalization(float(args.livetime), float(args.rmcn1emin), internal=1, run_mode=str(args.BB))
      print("InternalRMCPhaseSpace1N_yield=",Yield)
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
    parser.add_argument("--rmcn0emin", help="min energy cut rmc 0N")
    parser.add_argument("--rmcn1emin", help="min energy cut rmc 1N")
    parser.add_argument("--prc", help="process")
    parser.add_argument("--printpot", help="print pot", default="no")
    parser.add_argument("--tmin", help="tmin", default=0)
    parser.add_argument("--internal", help="internal", default=1)
    parser.add_argument("--nsig", help="internal")
    parser.add_argument("--verbose", help="enable verbose debug output", default="false")
    args = parser.parse_args()
    main(args)

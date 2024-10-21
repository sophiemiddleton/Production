#! /usr/bin/env
import DbService
import argparse
import ROOT
import math
import os


# get muon stopped rates from DB
dbtool = DbService.DbTool()
dbtool.init()
args=["print-run","--purpose","MDC2020_best","--version","v1_1","--run","1200","--table","SimEfficiencies2","--content"]
dbtool.setArgs(args)
dbtool.run()
rr = dbtool.getResult()


# get number of target muon stops:
target_stopped_mu_per_POT = 1.0
rate = 1.0
lines= rr.split("\n")
for line in lines:
    words = line.split(",")
    if words[0] == "MuminusStopsCat" or words[0] == "MuBeamCat" :
        #print(f"Including {words[0]} with rate {words[3]}")
        rate = rate * float(words[3])
        target_stopped_mu_per_POT = rate * 1000 
#print(f"Final stops rate muon {target_stopped_mu_per_POT}")



# get number of POTs in given livetime
def livetime_to_pot(livetime, run_mode = '1BB',printout=False): #livetime in seconds
    # numbers from SU2020 
    # see https://github.com/Mu2e/su2020/blob/master/analysis/pot_normalization.org
    NPOT = 0.
    if(run_mode == '1BB'):
      # 1BB
      mean_PBI_low = 1.6e7
      Tcycle = 1.33 #s
      onspill_dutyfactor = 0.323
      POT_per_cycle = 4e12
      #onspill_time = livetime*onspill_dutyfactor
      Ncycles = livetime/Tcycle
      NPOT = Ncycles * POT_per_cycle
      if( printout):
        print("Tcycle=",Tcycle)
        print("POT_per_cycle=",POT_per_cycle)
        print("onspilltime=",livetime*onspill_dutyfactor)
        print ("NPOT=",NPOT)
    if(run_mode == '2BB'):
      # 2BB
      mean_PBI_high = 3.9e7
      Tcycle = 1.4 #s
      onspill_dutyfactor = 0.246
      POT_per_cycle = 8e12
      #onspill_time = livetime*onspill_dutyfactor
      Ncycles = livetime/Tcycle
      NPOT = Ncycles * POT_per_cycle
      if( printout):
        print("Tcycle=",Tcycle)
        print("POT_per_cycle=",POT_per_cycle)
        print("onspilltime=",livetime*onspill_dutyfactor)
        print ("NPOT=",NPOT)
    return NPOT

# get number of ipa muon stops:
ipa_stopped_mu_per_POT = 1.0
rate = 1.0
lines= rr.split("\n")
for line in lines:
    words = line.split(",")
    if words[0] == "IPAStopsCat" or words[0] == "MuBeamCat" :
        #print(f"Including {words[0]} with rate {words[3]}")
        rate = rate * float(words[3])
        ipa_stopped_mu_per_POT = rate
#print(f"Final ipa stops rate {ipa_stopped_mu_per_POT}")

# get CE normalization:
def ce_normalization(livetime, rue, run_mode = '1BB'):
    POT = livetime_to_pot(livetime, run_mode)
    captures_per_stopped_muon = 0.609 # for Al
    #print(f"Expected CE's {POT * target_stopped_mu_per_POT * captures_per_stopped_muon * rue}")
    return POT * target_stopped_mu_per_POT * captures_per_stopped_muon * rue

# get IPA Michel normalization:
def ipaMichel_normalization(livetime):
    POT = livetime_to_pot(livetime)
    IPA_decays_per_stopped_muon = 0.92 # carbon....#TODO
    #print(f"Expected IPA Michel e- {POT * ipa_stopped_mu_per_POT * IPA_decays_per_stopped_muon}")
    return POT * ipa_stopped_mu_per_POT * IPA_decays_per_stopped_muon

# get DIO normalization:
def dio_normalization(livetime, emin, run_mode = '1BB'):
    POT = livetime_to_pot(livetime, run_mode)
    # calculate fraction of spectrum generated
    spec = open(os.path.join(os.environ["MUSE_WORK_DIR"],"Production/JobConfig/ensemble/heeck_finer_binning_2016_szafron.tbl")) 
    energy = []
    val = []
    for line in spec:
        energy.append(float(line.split()[0]))
        val.append(float(line.split()[1]))

    total_norm = 0
    cut_norm = 0
    for i in range(len(val)):
        total_norm += val[i]
        if energy[i] >= emin:
            cut_norm += val[i]

    DIO_per_stopped_muon = 0.391 # 1 - captures_per_stopped_muon

    physics_events = POT * target_stopped_mu_per_POT * DIO_per_stopped_muon
    #print(f"Expected DIO {physics_events* cut_norm/total_norm}")
    print("DIOfrac=",cut_norm/total_norm)
    return physics_events * cut_norm/total_norm


# note this returns CosmicLivetime not # of generated events
def cry_onspill_normalization(livetime, run_mode = '1BB'):
    onspill_dutyfactor = 1.
    if(run_mode == '1BB'):
      # 1BB
      onspill_dutyfactor = 0.323
    if(run_mode == '2BB'):
      # 2BB
      onspill_dutyfactor = 0.246
    #print(f"cosmics live time {livetime*onspill_dutyfactor}")
    return livetime*onspill_dutyfactor

# note this returns CosmicLivetime not # of generated events
def cry_offspill_normalization(livetime, run_mode = '1BB'):
    offspill_dutyfactor = 1.
    if(run_mode == '1BB'):
      # 1BB
      offspill_dutyfactor = 0.323
    if(run_mode == '2BB'):
      # 2BB
      offspill_dutyfactor = 0.246
    #print(f"cosmics live time {livetime*offspill_dutyfactor}")
    return livetime*offspill_dutyfactor
    
# note this returns CosmicLivetime not # of generated events
def corsika_onspill_normalization(livetime, run_mode = '1BB'):
    onspill_dutyfactor = 1.
    if(run_mode == '1BB'):
      # 1BB
      onspill_dutyfactor = 0.323
    if(run_mode == '2BB'):
      # 2BB
      onspill_dutyfactor = 0.246
    #print(f"cosmics live time {livetime*onspill_dutyfactor}")
    return livetime*onspill_dutyfactor

# note this returns CosmicLivetime not # of generated events
def corsika_offspill_normalization(livetime, run_mode = '1BB'):
    offspill_dutyfactor = 1.
    if(run_mode == '1BB'):
      # 1BB
      offspill_dutyfactor = 0.323
    if(run_mode == '2BB'):
      # 2BB
      offspill_dutyfactor = 0.246
    #print(f"cosmics live time {livetime*offspill_dutyfactor}")
    return livetime*offspill_dutyfactor
    
"""
# get stopped rates from DB
dbtool = DbService.DbTool()
dbtool.init()
args=["print-run","--purpose","MDC2020_best","--version","v1_1","--run","1200","--table","PiEfficiencies","--content"] 
# TODO make new pi table
dbtool.setArgs(args)
dbtool.run()
rpi = dbtool.getResult()


# get number of target pions stops:
target_stopped_pi_per_POT = 1.0
nstops = 1.0
pirate = 1.0
lines= rpi.split("\n")
for line in lines:
    words = line.split(",")
    if words[0] == "PiminusStopsCat" or words[0] == "PiBeamCat" or words[0] == "PiMinusFilter" :
        print(f"Including {words[0]} with pirate {words[3]}")
        pirate = pirate * float(words[3]) # stops_per_POT
    if words[0] == "PiminusStopsCat":
      npistops = words[1]   
    if words[0] == "PiMinusFilter" :
        print(f"Including {words[0]} with pirate {words[3]}")
        timeeff = float(words[3])
        target_stopped_pi_per_POT = pirate * timeeff # stops_per_POT*time_eff
print(f"Final stops pirate pion {target_stopped_pi_per_POT}")
"""

# hack: --> will come from new table eventually
nstops = 1287106
target_stopped_pi_per_POT = 0.00493 * 0.01288394 * 0.1670400

# constants
RPC_per_stopped_pion = 0.0215; # from reference, uploaded on docdb-469
internalRPC_per_RPC = 0.00690; # from reference, uploaded on docdb-717
def rpc_normalization(livetime, emin, tmin, internal):
  # calculate fraction of spectrum being generated
  
  spec = open(os.path.join(os.environ["MUSE_WORK_DIR"],"Production/JobConfig/ensemble/RPCspectrum.tbl")) 
  # Bistirlich spectrum from 0.05 to 139.95 in steps of 0.1
  energy = []
  val = []
  for line in spec:
    energy.append(float(line.split()[0]))
    val.append(float(line.split()[1]))
  bin_width = energy[1]-energy[0];

  total_norm = 0
  cut_norm = 0
  for i in range(len(val)):
    total_norm += val[i]
    if (energy[i]-bin_width/2. >= emin):
      cut_norm += val[i]

  # calculate survival probability for tmin including smearing of POT
  f = old ntuple
  d = old dumper
  t = old stops treee
  total = 0;
  for i in range(t.GetEntries()):
    t.GetEntry(i)
    total += math.exp(-t.tauNormalized);
  avg_survival_prob = total/t.GetEntries();

  physics_events = POT * target_stopped_pi_per_POT * RPC_per_stopped_pion * avg_survival_prob
  gen_events = physics_events * cut_norm/total_norm;

  if internal == 1:
    physics_events *= internalRPC_per_RPC;
    gen_events *= internalRPC_per_RPC;

  return gen_events


def pot_to_livetime(pot):
    return pot / POT_per_second

if __name__ == '__main__':
  tst_1BB = livetime_to_pot(9.52e6)
  tst_2BB = livetime_to_pot(1.58e6)
  tst_rpc = rpc_normalization(1e6,0,350,1)
  print("SU2020", tst_1BB, tst_2BB)

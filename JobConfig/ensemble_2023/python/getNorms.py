import DbService
import ROOT
import math
import os

# numbers from SU2020
mean_PBI_low = 1.6e7
mean_PBI_high = 3.9e7
mean_PBI = mean_PBI_low*0.75 + mean_PBI_high*0.25
dutyfactor = 0.323 
ub_per_year = (365*24*60*60./1695e-9)*dutyfactor
POT_per_year = ub_per_year*mean_PBI


# get stopped rates from DB
dbtool = DbService.DbTool()
dbtool.init()
args=["print-run","--purpose","MDC2020_best","--version","v1_1","--run","1200","--table","SimEfficiencies2","--content"]
dbtool.setArgs(args)
dbtool.run()
rr = dbtool.getResult()
#print(rr)
lines= rr.split("\n")

# get number of target muon stops:
target_stopped_mu_per_POT = 1.0
rate = 1.0
for line in lines:
    words = line.split(",")
    if words[0] == "MuminusStopsCat" or words[0] == "MuBeamCat" :
        print(f"Including {words[0]} with rate {words[3]}")
        rate = rate * float(words[3])
        target_stopped_mu_per_POT = rate * 1000 
print(f"Final stops rate {target_stopped_mu_per_POT}")

# get number of ipa muon stops:
ipa_stopped_mu_per_POT = 1.0
rate = 1.0
for line in lines:
    words = line.split(",")
    if words[0] == "IPAStopsCat" or words[0] == "MuBeamCat" :
        print(f"Including {words[0]} with rate {words[3]}")
        rate = rate * float(words[3])
        ipa_stopped_mu_per_POT = rate
print(f"Final ipa stops rate {ipa_stopped_mu_per_POT}")

# get CE normalization:
def ce_normalization(livetime, rue): # livetime in fractions of year?
  captures_per_stopped_muon = 0.609 # for Al
  print("Expected CE's", POT_per_year * target_stopped_mu_per_POT * captures_per_stopped_muon * livetime * rue)
  return POT_per_year * target_stopped_mu_per_POT * captures_per_stopped_muon * livetime * rue

# get IPA Michel normalization:
def ipaMichel_normalization(livetime):
  IPA_decays_per_stopped_muon = 0.92 # carbon
  print("Expected IPA Michel e- ", POT_per_year * ipa_stopped_mu_per_POT * IPA_decays_per_stopped_muon * livetime)
  return POT_per_year * ipa_stopped_mu_per_POT * IPA_decays_per_stopped_muon * livetime

# get DIO normalization:
def dio_normalization(livetime, emin):
  # calculate fraction of spectrum generated
  #spec = open(os.path.join(os.environ["MUSE_WORK_DIR"],"Production/JobConfig/ensemble_2023/heeck_finer_binning_2016_szafron.tbl")) TODO - needs to be put back once in HEAD
  spec = open(os.path.join("heeck_finer_binning_2016_szafron.tbl"))
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

  physics_events = POT_per_year * target_stopped_mu_per_POT * DIO_per_stopped_muon * livetime
  print("Expected DIO ",physics_events* cut_norm/total_norm)
  return physics_events * cut_norm/total_norm
  
# for testing only
if __name__ == '__main__':
  ce_normalization(3.5e6/1.1e7, 1e-14)
  ipaMichel_normalization(3.5e6/1.1e7)
  dio_normalization(3.5e6/1.1e7,75)

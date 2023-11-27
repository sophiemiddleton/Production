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
target_stopped_mu_per_POT = 1.0
rate = 1.0
for line in lines:
    words = line.split(",")
    if words[0] == "MuminusStopsCat" or words[0] == "MuBeamCat" :
        print(f"Including {words[0]} with rate {words[3]}")
        rate = rate * float(words[3])
        target_stopped_mu_per_POT = rate * 1000 
print(f"Final stops rate {target_stopped_mu_per_POT}")

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
  print(POT_per_year , target_stopped_mu_per_POT , captures_per_stopped_muon , livetime , rue, POT_per_year * target_stopped_mu_per_POT * captures_per_stopped_muon * livetime * rue)
  return POT_per_year * target_stopped_mu_per_POT * captures_per_stopped_muon * livetime * rue


# for testing only
if __name__ == '__main__':
  ce_normalization(3.5e6/1.1e7, 1e-14)

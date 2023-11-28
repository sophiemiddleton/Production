import DbService
import ROOT
import math
import os

# numbers from SU2020
mean_PBI_low = 1.6e7
mean_PBI_high = 3.9e7
mean_PBI = mean_PBI_low*0.75 + mean_PBI_high*0.25
onspill_dutyfactor = 0.323
offspill_dutyfactor = 0.323
ub_per_second = 1/1695e-9*onspill_dutyfactor
POT_per_second = ub_per_second*mean_PBI


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
def ce_normalization(livetime, rue):
    POT = livetime_to_pot(livetime)
    captures_per_stopped_muon = 0.609 # for Al
    print("Expected CE's", POT * target_stopped_mu_per_POT * captures_per_stopped_muon * rue)
    return POT * target_stopped_mu_per_POT * captures_per_stopped_muon * rue

# get IPA Michel normalization:
def ipaMichel_normalization(livetime):
    POT = livetime_to_pot(livetime)
    IPA_decays_per_stopped_muon = 0.92 # carbon
    print("Expected IPA Michel e- ", POT * ipa_stopped_mu_per_POT * IPA_decays_per_stopped_muon)
    return POT * ipa_stopped_mu_per_POT * IPA_decays_per_stopped_muon

# get DIO normalization:
def dio_normalization(livetime, emin):
    POT = livetime_to_pot(livetime)
    # calculate fraction of spectrum generated
    spec = open(os.path.join(os.environ["MUSE_WORK_DIR"],"Production/JobConfig/ensemble_2023/heeck_finer_binning_2016_szafron.tbl")) #TODO - needs to be put back once in HEAD
    #spec = open(os.path.join("heeck_finer_binning_2016_szafron.tbl"))
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
    print("Expected DIO ",physics_events* cut_norm/total_norm,POT,target_stopped_mu_per_POT,DIO_per_stopped_muon,cut_norm/total_norm,physics_events)
    return physics_events * cut_norm/total_norm

# note this returns CosmicLivetime not # of generated events
def cry_onspill_normalization(livetime):
    return livetime*onspill_dutyfactor

# note this returns CosmicLivetime not # of generated events
def cry_offspill_normalization(livetime):
    return livetime*offspill_dutyfactor

def livetime_to_pot(livetime): #livetime in seconds
    return livetime * POT_per_second

def pot_to_livetime(pot):
    return pot / POT_per_second

# for testing only
if __name__ == '__main__':
    livetime = pot_to_livetime(3.5e6)
    ce_normalization(livetime, 1e-14)
    ipaMichel_normalization(livetime/1.1e7)
    dio_normalization(livetime,75)
    cry_onspill_normalization(livetime)

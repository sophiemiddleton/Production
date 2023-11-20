import ROOT
import math
import os

# TODO - which of these numbers are needed?
mean_PBI_low = 1.6e7
mean_PBI_high = 3.9e7
pulses_per_second = 1/(1695e-9)
mean_PBI = mean_PBI_low*0.75 + mean_PBI_high*0.25
dutyfactor = 0.323 # from SU2020
ub_per_year = 365*24*60*60./1695e-9*dutyfactor
#POT_low = dutyfactor*pulses_per_second*mean_PBI_low*livetime
#POT_high = dutyfactor*pulses_per_second*mean_PBI_high*livetime
POT_per_year = ub_per_year*mean_PBI
stopped_mu_per_POT = 0.00155

def cry_normalization(livetime):
  cry_expected_rate = 253440 #Hz
  cry_tmin = 450e-9
  cry_tmax = 1705e-9
  cry_expected_per_ub = cry_expected_rate*(cry_tmax-cry_tmin)
  cry_expected_per_year = ub_per_year * cry_expected_per_ub
  return cry_expected_per_year * livetime

def corsika_normalization(livetime): ### TODO: we need to get this rate!!!!!
  cry_expected_rate = 253440 #Hz
  cry_tmin = 450e-9
  cry_tmax = 1705e-9
  cry_expected_per_ub = cry_expected_rate*(cry_tmax-cry_tmin)
  cry_expected_per_year = ub_per_year * cry_expected_per_ub
  return cry_expected_per_year * livetime

def ipaMichel_normalization(livetime):
  IPA_stopped_mu_per_POT = 8e-8
  IPA_decays_per_stopped_muon = 0.92 # carbon

  return POT_per_year * IPA_stopped_mu_per_POT * IPA_decays_per_stopped_muon * livetime
  
def ce_normalization(livetime, rue):
  captures_per_stopped_muon = 0.609
  return POT_per_year * stopped_mu_per_POT * captures_per_stopped_muon * livetime * rue

def dio_normalization(livetime, emin):
  # calculate fraction of spectrum being generated
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

  physics_events = POT_per_year * stopped_mu_per_POT * DIO_per_stopped_muon * livetime
  return physics_events * cut_norm/total_norm

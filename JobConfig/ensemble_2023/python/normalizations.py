import ROOT
import math
import os

mean_PBI = 3.9e7 # in JobConfig/mixing/prolog.fcl  protonBunchIntensity.extendedMean
dutyfactor = 0.25 # 43.1ms+5ms on spill x8, then 1020ms off spill
ub_per_year = 365*24*60*60./1695e-9*dutyfactor
POT_per_year = ub_per_year*mean_PBI
stopped_mu_per_POT = 0.00187

def cry_normalization(livetime):
  cry_expected_rate = 253440 #Hz
  cry_tmin = 450e-9
  cry_tmax = 1705e-9
  cry_expected_per_ub = cry_expected_rate*(cry_tmax-cry_tmin)
  cry_expected_per_year = ub_per_year * cry_expected_per_ub
  return cry_expected_per_year * livetime


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

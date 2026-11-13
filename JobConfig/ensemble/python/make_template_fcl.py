#! /usr/bin/env python
from string import Template
import argparse
import sys
import random
import os
import glob
import ROOT
from normalizations import *
import subprocess
import math

"""
How to use:
python ../Production/JobConfig/ensemble/python/make_template_fcl.py --BB=1BB --verbose=1 --rue=1e-13 --livetime=60 --run=1201 --dioemin=75 --tmin=450 --samplingseed=1  --prc "CE" "DIO"
"""

def cosmic_subrun_livetime(t, lt_branch, gc_branch, n_gen_s1, lt_s1):
  """
  Sum the resampled cosmic livetime over the SubRuns tree t, correcting the
  Mu2eProductMixer integer-division bug (Mu2e/Offline#1940), which stored
  floor(N_res/N_gen)*L_S1 instead of (N_res/N_gen)*L_S1.
  N_res is the S2 draw count (genCounter runs before the resampler);
  n_gen_s1 and lt_s1 are the S1 pool's per-subrun generated count and livetime.
  Files made after the fix are recognised and their stored value is kept.
  S1 subruns differ slightly in livetime (~0.1%), so the match is loose; the
  buggy case is tested first, since where both match true_lt is the safe answer.
  """
  tol = 0.01
  total = 0.
  for i in range(t.GetEntries()):
      t.GetEntry(i)
      stored = getattr(t, lt_branch).product().liveTime()
      n_res = getattr(t, gc_branch).product().count()
      r = n_res / n_gen_s1
      true_lt = r * lt_s1
      buggy_lt = math.floor(r) * lt_s1
      if math.isclose(stored, buggy_lt, rel_tol=tol, abs_tol=1e-6):
          total += true_lt
      elif math.isclose(stored, true_lt, rel_tol=tol):
          total += stored
      else:
          implied = stored / math.floor(r) if math.floor(r) > 0 else float("nan")
          raise RuntimeError("CosmicLivetime %f matches neither corrected %f nor buggy %f "
                             "(N_res %d, r %.4f, implied S1 livetime %f); check --cosmic-ngen and "
                             "--cosmic-s1-livetime" % (stored, true_lt, buggy_lt, n_res, r, implied))
  return total

def main(args):

  # live time in seconds
  livetime = float(args.livetime)

  # r mue and rmup rates
  #rue = float(args.rue)

  dioemin = float(args.dioemin)
  tmin = float(args.tmin)
  run = int(args.run)
  samplingseed = int(args.samplingseed)
  processes = ""
  for i, j in enumerate(args.prc):
    processes +=str(j)

  ROOT.gRandom.SetSeed(0)

  # Convert args.prc into a set for fast lookup
  requested_processes = set(args.prc)
  
  # Initialize an empty dictionary
  norms = {}

  # Only call functions and define keys if they are in the requested processes
  if "CRYCosmic" in requested_processes:
      norms["CRYCosmic"] = cry_onspill_normalization(livetime, args.BB)
      
  if "CORSIKACosmic" in requested_processes:
      norms["CORSIKACosmic"] = corsika_onspill_normalization(livetime, args.BB)
      
  if "DIO" in requested_processes:
      norms["DIO"] = dio_normalization(livetime, dioemin, args.BB)
      
  if "RPCInternal" in requested_processes:
      norms["RPCInternal"] = rpc_normalization(livetime, tmin, 1, args.rpcemin, args.BB)
      
  if "RPCExternal" in requested_processes:
      norms["RPCExternal"] = rpc_normalization(livetime, tmin, 0, args.rpcemin, args.BB)
      
  if "RMCInternal" in requested_processes:
      norms["RMCInternal"] = rmc_normalization(livetime, 1, args.rmcemin, args.rmckmax, args.BB)
      
  if "RMCExternal" in requested_processes:
      norms["RMCExternal"] = rmc_normalization(livetime, 0, args.rmcemin, args.rmckmax, args.BB)
      
  if "RMCN0External" in requested_processes or "RMCPhaseSpace0NExternal" in requested_processes:
      norms["RMCN0External"] = norms["RMCPhaseSpace0NExternal"] = rmc_0n_normalization(livetime, args.rmcn0emin, internal=0, run_mode=args.BB)
      
  if "RMCN0Internal" in requested_processes or "RMCPhaseSpace0NInternal" in requested_processes:
      norms["RMCN0Internal"] = norms["RMCPhaseSpace0NInternal"] = rmc_0n_normalization(livetime, args.rmcn0emin, internal=1, run_mode=args.BB)
      
  if "RMCN1External" in requested_processes or "RMCPhaseSpace1NExternal" in requested_processes:
      norms["RMCN1External"] = norms["RMCPhaseSpace1NExternal"] = rmc_1n_normalization(livetime, args.rmcn1emin, internal=0, run_mode=args.BB)
      
  if "RMCN1Internal" in requested_processes or "RMCPhaseSpace1NInternal" in requested_processes:
      norms["RMCN1Internal"] = norms["RMCPhaseSpace1NInternal"] = rmc_1n_normalization(livetime, args.rmcn1emin, internal=1, run_mode=args.BB)
      
  if "IPAMichel" in requested_processes:
      norms["IPAMichel"] = ipaMichel_normalization(livetime, args.ipaemin, args.BB)

  starting_event_num = {}
  max_possible_events = {}
  mean_reco_events = {}
  filenames = {}
  current_file = {}

  # loop over each "signal"
  for signal in args.prc:
      print(signal)
      #FIXME starting and ending event
      
      # open file list from the filelists directory
      ffns = open(os.path.join("filenames_%s" % signal))
      
      # add empty file list
      filenames[signal] = []
      
      # enter empty entry for current file
      current_file[signal] = 0
      
      # enter empty entry for starting event
      starting_event_num[signal] = [0,0,0]

      # start counters
      reco_events = 0
      gen_events = 0
      livetime=0
      # loop over files in list
      for line in ffns:
          
          # find a given filename
          fn = line.strip()
          
          # add this filename to the list of filenames
          filenames[signal].append(fn)
          
          # use ROOT to get the events in that file
          fin = ROOT.TFile(fn)
          te = fin.Get("Events")

          # determine total number of events surviving all cuts
          reco_events += te.GetEntries()
          if int(args.verbose) == 2:
            print(" reco events ", reco_events)
        
          # determine total number of events generated
          t = fin.Get("SubRuns")
          
          # things are slightly different for the Cosmics:
          if signal == "CRYCosmic" or signal == "CORSIKACosmic":
              # find the right branch
              bl = t.GetListOfBranches()
              bn = ""
              gc = ""

              for i in range(bl.GetEntries()):
                  name = bl[i].GetName()
                  # prefer the resampler's "mixed" instance, which carries the bug
                  if name.startswith("mu2e::CosmicLivetime") and (bn == "" or "_mixed_" in name):
                      bn = name
                  if name.startswith("mu2e::GenEventCount_genCounter_"):
                      gc = name
              if "_mixed_" in bn and gc != "":
                  lt = cosmic_subrun_livetime(t, bn, gc, float(args.cosmic_ngen), float(args.cosmic_s1_livetime))
              else:
                  # not resampled (or no draw count): the stored value is used as is
                  print("WARNING: %s: no mixed CosmicLivetime or genCounter, livetime not corrected" % fn)
                  lt = 0.
                  for i in range(t.GetEntries()):
                      t.GetEntry(i)
                      lt += getattr(t,bn).product().liveTime()
              livetime += lt
              gen_events += lt
          else:
              # find the right branch
              bl = t.GetListOfBranches()
              bn = ""
              # find number of generated events via the GenEventCount field:
              for i in range(bl.GetEntries()):
                  if bl[i].GetName().startswith("mu2e::GenEventCount"):
                      bn = bl[i].GetName()
              for i in range(t.GetEntries()):
                  t.GetEntry(i)
                  gen_events += getattr(t,bn).product().count()
          
          #if signal == "RPCInternal" or signal == "RPCExternal":
          #  gen_events *= float(args.surv) # survival probability
          
          if int(args.verbose) == 2:
            print("total gen events ",gen_events)

      # mean is the normalized number of that event type as expected
      mean_gen_events = norms[signal]
      if int(args.verbose) == 1:
        print("mean_reco_events",mean_gen_events,reco_events,float(gen_events))
      
      # factors in efficiency
      mean_reco_events[signal] = mean_gen_events*reco_events/float(gen_events) 
      print("NORM",mean_gen_events,"RECO",reco_events, "GEN",float(gen_events),"EXPECTED EVENTS:",mean_reco_events[signal] )
      if int(args.verbose) == 1:
        print(signal,"GEN_EVENTS:",gen_events,"RECO_EVENTS:",reco_events,"EXPECTED EVENTS:",mean_reco_events[signal])

  # poisson sampling:
  total_sample_events = ROOT.gRandom.Poisson(sum(mean_reco_events.values()))
  if int(args.verbose) == 1:
    print("TOTAL EXPECTED EVENTS:",sum(mean_reco_events.values()),"GENERATING:",total_sample_events)

  # calculate the normalized weights for each signal
  weights = {signal: mean_reco_events[signal]/float(total_sample_events) for signal in mean_reco_events}
  if int(args.verbose) == 1:
    print("weights " , weights)

  # generate subrun by subrun

  # open the SamplingInput template:
  fin = open(os.path.join(os.environ["MUSE_WORK_DIR"],"Production/JobConfig/ensemble/fcl/SamplingInput.fcl"))
  t = Template(fin.read())

  subrun = 0
  num_events_already_sampled = 0
  problem = False

  # this parameter controls how many events per fcl file:
  max_events_per_subrun = 10000000#10000
  while True:
      # split into "subruns" as requested by the max_events_per_subrun parameter
      events_this_run = max_events_per_subrun
      if num_events_already_sampled + events_this_run > total_sample_events:
          events_this_run = total_sample_events - num_events_already_sampled

      # loop over signals via weights. Add text based on weight and file names
      datasets = ""
      for signal in weights:
          datasets += "      %s: {\n" % (signal)
          datasets += "        fileNames : [\"%s\"]\n" % (filenames[signal][current_file[signal]])
          datasets += "        weight : %e\n" % (weights[signal])
          # add information on starting event, useful when have multiple .fcl per run
          if starting_event_num[signal] != [0,0,0]:
              datasets += "        skipToEvent : \"%d:%d:%d\"\n" % (starting_event_num[signal][0],starting_event_num[signal][1],starting_event_num[signal][2])
          datasets += "      }\n"

      d = {}
      d["datasets"] = datasets
      d["outnameMC"] = os.path.join("dts.mu2e.ensemble."+args.release+"_"+args.tag+".%06d_%08d.art" % (run,subrun))
      d["outnameData"] = os.path.join("dts.mu2e.ensemble."+args.release+"_"+args.tag+".%06d_%08d.art" % (run,subrun))
      d["run"] = run
      d["subRun"] = subrun
      d["samplingSeed"] = samplingseed + subrun
      # put all the exact parameter values in the fcl file
      d["comments"] = "#livetime: %f\n#dioemin: %f\n#tmin: %f\n#run: %f\n#nevts: %d\n" % (livetime,dioemin,tmin,run,events_this_run)

      # make the .fcl file for this subrun (subrun # d)
      fout = open(os.path.join("SamplingInput_sr%d.fcl" % (subrun)),"w")
      fout.write(t.substitute(d))
      fout.close()

      num_events_already_sampled += events_this_run
    
      if problem:
          print("Error detected, exiting")
          sys.exit(1)
      if num_events_already_sampled >= total_sample_events:
          break
      subrun+=1
      return events_this_run
      
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", help="verbose")
    parser.add_argument("--BB", help="BB mode e.g. 1BB")
    parser.add_argument("--release", help="e.g. MDC2020ad")
    parser.add_argument("--livetime", help="simulated livetime")
    parser.add_argument("--tmin", help="arrival time cut")
    parser.add_argument("--dioemin", help="min energy cut dio")
    parser.add_argument("--rpcemin", help="min energy cut rpc")
    parser.add_argument("--ipaemin", help="min energy cut ipa")
    parser.add_argument("--rmcemin", help="min energy cut rmc")
    parser.add_argument("--rmcn0emin", help="min energy cut rmc 0N")
    parser.add_argument("--rmcn1emin", help="min energy cut rmc 1N")
    parser.add_argument("--rmckmax", help="kmax theory value")
    parser.add_argument("--run", help="run number")
    parser.add_argument("--samplingseed", help="samplingseed")
    parser.add_argument("--tag", help="ouput file tag")
    parser.add_argument("--prc", help="list of signals e.g CE DIO Cosmic", nargs='+')
    parser.add_argument("--cosmic-ngen", default=128783, help="S1 cosmic pool generated events per subrun (CosmicDSStopsCRYAll.MDC2025ab)")
    parser.add_argument("--cosmic-s1-livetime", default=29.586, help="S1 cosmic pool livetime per subrun [s] (CosmicDSStopsCRYAll.MDC2025ab)")
    args = parser.parse_args()
    (args) = parser.parse_args()
    main(args)

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

"""
How to use:
python ../Production/JobConfig/ensemble/python/make_template_fcl.py --BB=1BB --verbose=1 --rue=1e-13 --livetime=60 --run=1201 --dem_emin=75 --tmin=450 --samplingseed=1  --prc "CE" "DIO"
"""

def main(args):
  
  # live time in seconds
  livetime = float(args.livetime)

  # r mue and rmup rates
  rue = float(args.rue)

  dem_emin = float(args.dem_emin)
  tmin = float(args.tmin)
  run = int(args.run)
  samplingseed = int(args.samplingseed)
  processes = ""
  for i, j in enumerate(args.prc):
    processes +=str(j)

  ROOT.gRandom.SetSeed(0)

  # extract normalization of each background/signal process:
  norms = {
          "DIO": dio_normalization(livetime,dem_emin, args.BB),
          "CE": ce_normalization(livetime,rue, args.BB),
          "CeMLL": ce_normalization(livetime,rue, args.BB),
          "CRYCosmic": cry_onspill_normalization(livetime, args.BB),
          "CORSIKACosmic": corsika_onspill_normalization(livetime, args.BB),
          "RPCInternal": rpc_normalization(livetime, args.tmin, 1, 1.0, args.BB),
          "RPCExternal": rpc_normalization(livetime, args.tmin, 0, 1.0, args.BB)
          }

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
      
      # loop over files in list
      for line in ffns:
          
          # find a given filename
          fn = line.strip()
          
          # add this filename to the list of filenames
          filenames[signal].append(fn)
          
          # use ROOT to get the events in that file
          fin = ROOT.TFile(fn)
          te = fin.Get("Events")
          if signal == "RPCInternal" or signal == "RPCExternal":
                bl = te.GetListOfBranches()
                bn = ""
                for i in range(bl.GetEntries()):
                    if bl[i].GetName().startswith("mu2e::EventWeight"):
                        bn = bl[i].GetName()
                for i in range(te.GetEntries()):
                    te.GetEntry(i)
                    reco_events += getattr(te,bn).product().weight()
          else:
            # determine total number of events surviving all cuts
            reco_events += te.GetEntries()
          if int(args.verbose) == 2:
            print(" reco events ", te.GetEntries())
        
          # determine total number of events generated
          t = fin.Get("SubRuns")
          
          # things are slightly different for the Cosmics:
          if signal == "CRYCosmic" or signal == "CORSIKACosmic":
              # find the right branch
              bl = t.GetListOfBranches()
              bn = ""
              for i in range(bl.GetEntries()):
                  if bl[i].GetName().startswith("mu2e::CosmicLivetime"):
                      bn = bl[i].GetName()
              for i in range(t.GetEntries()):
                  t.GetEntry(i)
                  gen_events += getattr(t,bn).product().liveTime()
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
          
          if signal == "RPCInternal" or signal == "RPCExternal":
            gen_events *= 1148/1287106 # to factor in lifetime - FIXME - automate this!!!!
          
          if int(args.verbose) == 2:
            print("total gen events ",gen_events)

      # mean is the normalized number of that event type as expected
      mean_gen_events = norms[signal]
      if int(args.verbose) == 1:
        print("mean_reco_events",mean_gen_events,reco_events,float(gen_events))
      
      # factors in efficiency
      mean_reco_events[signal] = mean_gen_events*reco_events/float(gen_events) 
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
      d["outnameMC"] = os.path.join("dts.mu2e.ensemble"+args.tag+"."+args.release+".%06d_%08d.art" % (run,subrun))
      d["outnameData"] = os.path.join("dts.mu2e.ensemble"+args.tag+"."+args.release+".%06d_%08d.art" % (run,subrun))
      d["run"] = run
      d["subRun"] = subrun
      d["samplingSeed"] = samplingseed + subrun
      # put all the exact parameter values in the fcl file
      d["comments"] = "#livetime: %f\n#rue: %f\n#dem_emin: %f\n#tmin: %f\n#run: %f\n#nevts: %d\n" % (livetime,rue,dem_emin,tmin,run,events_this_run)

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
    parser.add_argument("--rue", help="signal branching rate")
    parser.add_argument("--tmin", help="arrival time cut")
    parser.add_argument("--dem_emin", help="min energy cut")
    parser.add_argument("--run", help="run number")
    parser.add_argument("--samplingseed", help="samplingseed")
    parser.add_argument("--tag", help="ouput file tag")
    parser.add_argument("--prc", help="list of signals e.g CE DIO Cosmic", nargs='+')
    args = parser.parse_args()
    (args) = parser.parse_args()
    main(args)

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
python ../Production/Jobfilelists/ensemble/python/run_si_v2.py --outpath=/exp/mu2e/app/users/sophie/ProductionEnsembles/new-workflow/output/ --filelists=/exp/mu2e/app/users/sophie/ProductionEnsembles/new-workflow/filelists/ --BB=1BB --verbose=1 --rue=1e-13 --livetime=60 --run=1201 --dem_emin=75 --tmin=450 --samplingseed=1  --prc "CE" "DIO"


"""

def main(args):
  
  if int(args.verbose) == 1:
    print(" Running SI with options : verbose ",args.verbose," BB mode ", args.BB, " livetime [s] ", args.livetime, " Rmue ", args.rue)
    print(" filelists located in ", args.filelists)
    print(" Output passed to ", args.outpath)
    print(" Signals ", args.prc)
  
  if int(args.verbose) == 1:
    print("opening filelists ", args.filelists, " args.outpath is ",args.outpath)

  # live time in seconds
  livetime = float(args.livetime) #float(open(os.path.join(args.filelists,"livetime")).readline()) #in seconds

  if int(args.verbose) == 1:
    print("producing sample for livetime",livetime, "seconds")
    
  # r mue and rmup rates
  rue = float(args.rue)

  if int(args.verbose) == 1:
    print( "Rmue chosen ", rue)

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
          "DIOTail": dio_normalization(livetime,dem_emin, args.BB),
          "CeEndpoint": ce_normalization(livetime,rue, args.BB),
          #"CRYCosmic": cry_onspill_normalization(livetime),
          #"CORSIKACosmic": corsika_onspill_normalization(livetime),
          }

  starting_event_num = {}
  max_possible_events = {}
  mean_reco_events = {}
  filenames = {}
  current_file = {}

  # loop over each "signal"
  for signal in norms:
      print(signal)
      #FIXME starting and ending event
      
      # open file list from the filelists directory
      ffns = open(os.path.join(args.filelists,"filenames_%s" % signal))
      
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
          print("at line ", line, "of ", signal)
          
          # find a given filename
          fn = line.strip()
          print("striped filename ",fn)
          
          # add this filename to the list of filenames
          filenames[signal].append(fn)
          
          # use ROOT to get the events in that file
          fin = ROOT.TFile(fn)
          te = fin.Get("Events")

          # determine total number of events surviving all cuts
          reco_events += te.GetEntries()
          #print(" reco events ", te.GetEntries())
          
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
          #print("total gen events ",gen_events)

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
  max_events_per_subrun = 10000000
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
      d["outnameMC"] = os.path.join(args.outpath,"dts.mu2e.ensemble-"+str(processes)+"-"+str(int(livetime))+"s-p"+str(int(dem_emin))+"MeVc"+".MDC2020.%06d_%08d.art" % (run,subrun))
      d["outnameData"] = os.path.join(args.outpath,"dts.mu2e.ensemble-Data.MDC2020.%06d_%08d.art" % (run,subrun))
      d["run"] = run
      d["subRun"] = subrun
      d["samplingSeed"] = samplingseed + subrun
      # put all the exact parameter values in the fcl file
      d["comments"] = "#livetime: %f\n#rue: %f\n#dem_emin: %f\n#tmin: %f\n#run: %d\n" % (livetime,rue,dem_emin,tmin,run)

      # make the .fcl file for this subrun (subrun # d)
      fout = open(os.path.join(args.filelists,"SamplingInput_sr%d.fcl" % (subrun)),"w")
      fout.write(t.substitute(d))
      fout.close()

      # make a log file
      flog = open(os.path.join(args.filelists,"SamplingInput_sr%d.log" % (subrun)),"w")

      # run the fcl file using mu2e -c
      cmd = ["mu2e","-c",os.path.join(args.filelists,"SamplingInput_sr%d.fcl" % (subrun)),"--nevts","%d" % (events_this_run)]
      p = subprocess.Popen(cmd,stdout=subprocess.PIPE,universal_newlines=True)
      ready = False
      # loop over output of the process:
      for line in p.stdout:
          # write the files to log file TODO - time this effort
          flog.write(line)
          print(line)
          if "Dataset" in line.split() and "Counts" in line.split() and "fraction" in line.split() and "Next" in line.split():
              ready = True
              print("READY",ready)
          if ready:
              if len(line.split()) > 1:
                  signal = line.split()[0].strip()
                  if signal in starting_event_num:

                      if "no more available" in line:
                          starting_event_num[signal] = [0,0,0]
                          current_file[signal] += 1
                          if current_file[signal] >= len(filenames[signal]):
                              print("SIGNAL",signal,"HAS RUN OUT OF FILES!",current_file[signal])
                              problem = True
                      else:
                          new_run = int(line.strip().split()[-5])
                          new_subrun = int(line.strip().split()[-3])
                          new_event = int(line.strip().split()[-1])
                          starting_event_num[signal] = [new_run,new_subrun,new_event]
      p.wait()

      num_events_already_sampled += events_this_run
      print("Job done, return code: %d processed %d events out of %d" % (p.returncode,num_events_already_sampled,total_sample_events))
      if problem:
          print("Error detected, exiting")
          sys.exit(1)
      if num_events_already_sampled >= total_sample_events:
          break
      subrun+=1
      
      
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", help="verbose")
    parser.add_argument("--filelists", help="name of filelists directory with full path")
    parser.add_argument("--outpath", help="name of output directory with full path")
    parser.add_argument("--BB", help="BB mode e.g. 1BB")
    parser.add_argument("--livetime", help="simulated livetime")
    parser.add_argument("--rue", help="signal branching rate")
    parser.add_argument("--tmin", help="arrival time cut")
    parser.add_argument("--dem_emin", help="min energy cut")
    parser.add_argument("--run", help="run number")
    parser.add_argument("--samplingseed", help="samplingseed")
    parser.add_argument("--prc", help="list of signals e.g CE DIO Cosmic", nargs='+')
    args = parser.parse_args()
    (args) = parser.parse_args()
    main(args)

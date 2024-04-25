from string import Template
import sys
import random
import os
import glob
import ROOT
from normalizations import *
import subprocess

verbose = 1

dirname = sys.argv[1]
outpath = sys.argv[2]

if verbose == 1:
  print("opening config ", dirname, " outpath is ",outpath)

# live time in seconds
livetime = float(open(os.path.join(dirname,"livetime")).readline()) #in seconds

if verbose == 1:
  print("producing sample for livetime",livetime, "seconds")
  
# r mue and rmup rates
rue = float(open(os.path.join(dirname,"rue")).readline())
rup = float(open(os.path.join(dirname,"rup")).readline())

if verbose == 1:
  print( "Rmue chosen ", rue)
# for RMC backgrounds
kmax = 1.0 #float(open(os.path.join(dirname,"kmax")).readline())

fin = open(os.path.join(dirname,"settings"))
lines = fin.readlines()

# minimum momentum and time
dem_emin = float(lines[0])
print("min mom",dem_emin)
dep_emin = float(lines[1])
tmin = float(lines[2])
# maximum live time
max_livetime = float(lines[3]) # in seconds
run = int(lines[4])
samplingseed = int(lines[5])


ROOT.gRandom.SetSeed(0)

# extract normalization of each background/signal process:
norms = {
        "DIOTail": dio_normalization(livetime,dem_emin),
        "CeEndpoint": ce_normalization(livetime,rue),
        #"CRYCosmic": cry_onspill_normalization(livetime),
        #"CORSIKACosmic": corsika_onspill_normalization(livetime),
        #"IPAMichel": ipaMichel_normalization(livetime)
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
    
    # open file list from the config directory
    ffns = open(os.path.join(dirname,"filenames_%s" % signal))
    
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
    if verbose == 1:
      print("mean_reco_events",mean_gen_events,reco_events,float(gen_events))
    
    # factors in efficiency
    mean_reco_events[signal] = mean_gen_events*reco_events/float(gen_events) 
    if verbose == 1:
      print(signal,"GEN_EVENTS:",gen_events,"RECO_EVENTS:",reco_events,"EXPECTED EVENTS:",mean_reco_events[signal])

# poisson sampling:
total_sample_events = ROOT.gRandom.Poisson(sum(mean_reco_events.values()))
if verbose == 1:
  print("TOTAL EXPECTED EVENTS:",sum(mean_reco_events.values()),"GENERATING:",total_sample_events)

# calculate the normalized weights for each signal
weights = {signal: mean_reco_events[signal]/float(total_sample_events) for signal in mean_reco_events}
if verbose == 1:
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
    d["outnameMC"] = os.path.join(outpath,"dts.mu2e.ensemble-MC.MDC2020.%06d_%08d.art" % (run,subrun))
    d["outnameData"] = os.path.join(outpath,"dts.mu2e.ensemble-Data.MDC2020.%06d_%08d.art" % (run,subrun))
    d["run"] = run
    d["subRun"] = subrun
    d["samplingSeed"] = samplingseed + subrun
    # put all the exact parameter values in the fcl file
    d["comments"] = "#livetime: %f\n#rue: %e\n#rup: %e\n#kmax: %f\n#dem_emin: %f\n#dep_emin: %f\n#tmin: %f\n#max_livetime: %f\n#run: %d\n" % (livetime,rue,rup,kmax,dem_emin,dep_emin,tmin,max_livetime,run)

    # make the .fcl file for this subrun (subrun # d)
    fout = open(os.path.join(dirname,"SamplingInput_sr%d.fcl" % (subrun)),"w")
    fout.write(t.substitute(d))
    fout.close()

    # make a log file
    flog = open(os.path.join(dirname,"SamplingInput_sr%d.log" % (subrun)),"w")

    # run the fcl file using mu2e -c
    cmd = ["mu2e","-c",os.path.join(dirname,"SamplingInput_sr%d.fcl" % (subrun)),"--nevts","%d" % (events_this_run)]
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

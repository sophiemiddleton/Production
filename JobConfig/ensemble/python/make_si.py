from string import Template
import sys
import random
import os
import glob
import ROOT
from normalizations import *
import subprocess

verbose = 1

max_events_per_subrun = 50000

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

for signal in norms:
    print(signal)
    #FIXME starting and ending event

    ffns = open(os.path.join(dirname,"filenames_%s" % signal))
    filenames[signal] = []
    current_file[signal] = 0
    starting_event_num[signal] = [0,0,0]

    reco_events = 0
    gen_events = 0
    for line in ffns:
        print("at line ", line, "of ", signal)
        fn = line.strip()
        print("striped filename ",fn)
        filenames[signal].append(fn)
        fin = ROOT.TFile(fn)
        te = fin.Get("Events")

        # determine total number of events surviving all cuts
        reco_events += te.GetEntries()
        print(" reco events ", te.GetEntries())
        # determine total number of events generated
        t = fin.Get("SubRuns")
        if signal == "CRYCosmic":
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
            for i in range(bl.GetEntries()):
                if bl[i].GetName().startswith("mu2e::GenEventCount"):
                    bn = bl[i].GetName()
            for i in range(t.GetEntries()):
                t.GetEntry(i)
                gen_events += getattr(t,bn).product().count()
        print("total gen events ",gen_events)
        #print("ALL NAMES",filenames)

    mean_gen_events = norms[signal]
    print("mean_reco_events",mean_gen_events,reco_events,float(gen_events))
    mean_reco_events[signal] = mean_gen_events*reco_events/float(gen_events) # factors in efficiency
    # DEBUG ONLY
    print(signal,"GEN_EVENTS:",gen_events,"RECO_EVENTS:",reco_events,"EXPECTED EVENTS:",mean_reco_events[signal])
print("sum of means ",sum(mean_reco_events.values()))
total_sample_events = ROOT.gRandom.Poisson(sum(mean_reco_events.values()))
# DEBUG ONLY
print("TOTAL EXPECTED EVENTS:",sum(mean_reco_events.values()),"GENERATING:",total_sample_events)

# calculate the normalized weights for each signal
weights = {signal: mean_reco_events[signal]/float(total_sample_events) for signal in mean_reco_events}
print("weights " , weights)
# generate subrun by subrun
fin = open(os.path.join(os.environ["MUSE_WORK_DIR"],"Production/JobConfig/ensemble/fcl/SamplingInput.fcl"))
t = Template(fin.read())

subrun = 0
num_events_already_sampled = 0
problem = False

while True:
    events_this_run = max_events_per_subrun
    if num_events_already_sampled + events_this_run > total_sample_events:
        events_this_run = total_sample_events - num_events_already_sampled

    datasets = ""
    for signal in weights:
        datasets += "      %s: {\n" % (signal)
        datasets += "        fileNames : [\"%s\"]\n" % (filenames[signal][current_file[signal]])
        datasets += "        weight : %e\n" % (weights[signal])
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

    fout = open(os.path.join(dirname,"SamplingInput_sr%d.fcl" % (subrun)),"w")
    fout.write(t.substitute(d))
    fout.close()

    num_events_already_sampled += events_this_run
    
    if problem:
        print("Error detected, exiting")
        sys.exit(1)
    if num_events_already_sampled >= total_sample_events:
        break
    subrun+=1

#! /usr/bin/env python
from string import Template
import argparse
import sys
import random
import os
import glob
import ROOT
import subprocess

def main():
    prc = ["RPCInternal","StopPions"]
    processes = ""
    for i, j in enumerate(prc):
        processes +=str(j)

    ROOT.gRandom.SetSeed(0)

    starting_event_num = {}
    max_possible_events = {}
    mean_reco_events = {}
    filenames = {}
    current_file = {}

    # loop over each "signal"
    for signal in prc:
        print(signal)
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
        total_weight = 0

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
            print(" dts events ", reco_events)
            
            # determine total number of events generated
            t = fin.Get("Events")
            
            # things are slightly different for the Cosmics:
            if signal == "RPCInternal":
                # find the right branch
                bl = t.GetListOfBranches()
                bn = ""
                for i in range(bl.GetEntries()):
                    if bl[i].GetName().startswith("mu2e::EventWeight"):
                        bn = bl[i].GetName()
                for i in range(t.GetEntries()):
                    t.GetEntry(i)
                    total_weight += getattr(t,bn).product().weight()
            print(total_weight)


if __name__ == "__main__":
    main()
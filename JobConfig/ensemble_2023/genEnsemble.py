from __future__ import print_function
from string import Template
import sys
import random
import os
from normalizations import *
from argparse import ArgumentParser

def generate(dirname,max_livetime,run):
 
  random.seed()
  
  max_livetime_others = float(max_livetime)
  max_livetime_rmc = 1.0 # TODO remove this
  
  run_number = int(run)
  if os.path.exists(os.path.join(os.getcwd(), dirname)):
    print("Error: this directory exists!")
    sys.exit()

  os.system("mkdir " + dirname)

  livetime_fraction_min = 0.9
  livetime_fraction_max = 1.0
  livetime = max_livetime_others * random.uniform(livetime_fraction_min,livetime_fraction_max)

  if max_livetime_others <= 6/365.*20/24.:
    print("One week")
    # for one week
    rue_exp_min = -14
    rue_exp_max = -12.8
    rup_exp_min = -14
    rup_exp_max = -12.8
  else:
    print("One month")
    # for one month
    rue_exp_min = -14.6
    rue_exp_max = -13.4
    rup_exp_min = -14.6
    rup_exp_max = -13.4


  rue = 10**random.uniform(rue_exp_min,rue_exp_max)
  rup = 10**random.uniform(rup_exp_min,rup_exp_max)
  
  if rue > 2e-13:
    print("rue too high, change normalization")
    sys.exit()

  # Write the constants to a file - TODO do we need all of these?
  dem_emin = 93 # generated momentum minimum
  dep_emin = 83

  tmin = 400 # pion min time for generator

  fout = open(dirname + "/livetime","w")
  fout.write("%f\n" % (livetime*365*24*60*60))
  fout.close()
  fout = open(dirname + "/rue","w")
  fout.write("%e\n" % rue)
  fout.close()
  fout = open(dirname + "/rup","w")
  fout.write("%e\n" % rup)
  fout.close()
  fout = open(dirname + "/settings","w")
  fout.write("%f\n%f\n%f\n%f\n%d\n%d\n" % (dem_emin,dep_emin,tmin,max_livetime_rmc*0.95*365*24*60*60,run_number,random.randint(0,10000)))
  fout.close()

  # maximum expected events per year
  norms = {
    "DIOLeadingLog-cut-mix": dio_normalization(1,dem_emin),
    "CeMLeadingLog-mix": ce_normalization(1,10**rue_exp_max),
    "CePLeadingLog-mix": ce_normalization(1,10**rup_exp_max),
    }

  # these have been optimized for 93 MeV and 83 MeV for dem and dep respectively #TODO - need to understand this optimization
  per_run = {
    "DIOLeadingLog-cut-mix": 250,
    "CeMLeadingLog-mix": 250,
    "CePLeadingLog-mix": 250, 

    "reco-DIOLeadingLog-cut-mix": 25,
    "reco-CeMLeadingLog-mix": 25,
    "reco-CePLeadingLog-mix": 25,
    }

  for tname in ["CeMLeadingLog-mix","CePLeadingLog-mix"]:
    fin = open("Production/JobConfig/ensemble/generate_template.sh")
    temp_tname = tname[:-4] + "Mix"
    t = Template(fin.read())
    njobs = int(norms[tname]*max_livetime_others/per_run[tname])+1
    d = {"includeOrEmbed": "--include Production/JobConfig/mixing/" + temp_tname + ".fcl", "dirname": dirname, "name": tname, "njobs": njobs, "perjob": per_run[tname]}
    fout = open(dirname + "/generate_" + tname + ".sh","w")
    fout.write(t.substitute(d))
    fout.close()

if __name__ == "__main__":
    # new way of parsing arguments:
    # --dirname <dirname> --livetime <livetime> # in years --run <run number>
    parser = ArgumentParser()
    parser.add_argument("-p", "--dirname",dest="dirname", default="Test",
                        help="directory name")
    parser.add_argument("-l", "--livetime", dest="livetime", default="1",
                        help="livetime")
    parser.add_argument("-r", "--runnumber", dest="runnumber", default="1",
                        help="runnumber") 
    args = parser.parse_args()
    generate(args.dirname, args.livetime, args.runnumber)


    exit(0)


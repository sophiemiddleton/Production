#!/usr/bin/env python
from __future__ import print_function

from string import Template
import sys
import random
import os
from normalizations import *
from argparse import ArgumentParser

def generate(verbose=True):
    # when we run from SConscript, the cwd is the python subdir
    # but all file name are relative to Offline, so go there
    cwd = os.getcwd()
    words = cwd.split("/")
    if words[-1] == "ensemble" :
        os.chdir("../..")

    # lists of files to send to scons for dependencies
    sourceFiles = [
	"Production/JobConfig/ensemble/epilog.fcl","Production/JobConfig/ensemble/prolog.fcl",
	"Production/JobConfig/ensemble/epilog_reco.fcl","Production/JobConfig/ensemble/prolog_reco.fcl","Production/JobConfig/ensemble/reco-mcdigis-trig.fcl"]

    targetFiles = []

    projectDir = "build/gen/fcl/JobConfig/ensemble"
    if not os.path.exists(projectDir) :
      os.makedirs(projectDir)
    
    for tname in ["DIOLeadingLog-cut-mix"]:
      templateFileName = "Production/JobConfig/ensemble/" + tname + ".fcl"
      sourceFiles.append(templateFileName)
      fin = open(templateFileName) 
      t = Template(fin.read())
      d = {"minE": dem_emin, "particleTypes": [11, 13], "minMom": dem_emin}
      fclFileName = projectDir + "/" + tname + ".fcl"
      if verbose:
        print("Creating " + fclFileName)
      targetFiles.append(fclFileName)
      fout = open(fclFileName,"w")
      fout.write(t.substitute(d))
      fout.close()

      templateFileName = "Production/JobConfig/ensemble/reco-mcdigis-trig.fcl"
      fin = open(templateFileName)
      t = Template(fin.read())
      d = {"name": tname}
      fclFileName = projectDir + "/reco-" + tname + ".fcl"
      if verbose:
        print("Creating " + fclFileName)
      targetFiles.append(fclFileName)
      fout = open(fclFileName,"w")
      fout.write(t.substitute(d))
      fout.close()
    

    for tname in ["CeMLeadingLog-mix", "CePLeadingLog-mix"]:
      templateFileName = "Production/JobConfig/ensemble/reco-mcdigis-trig.fcl"
      fin = open(templateFileName)
      t = Template(fin.read())
      d = {"name": tname}
      fclFileName = projectDir + "/reco-" + tname + ".fcl"
      if verbose:
        print("Creating " + fclFileName)
      targetFiles.append(fclFileName)
      fout = open(fclFileName,"w")
      fout.write(t.substitute(d))
      fout.close()
 
    return sourceFiles, targetFiles


if __name__ == "__main__":

    parser = ArgumentParser()
    parser.add_argument("-q", "--quiet",
                        action="store_false", dest="verbose", default=True,
                        help="don't print status messages to stdout") 
    args = parser.parse_args()
    generate(args.verbose)


    exit(0)
      

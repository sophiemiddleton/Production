#!/usr/bin/env python
from __future__ import print_function

from string import Template
import sys
import random
import os
from normalizations import *
from argparse import ArgumentParser


def generate(verbose=True):
  # function needs to run normalizations
  # weight njobs accordingly
  # run gen_Mix for chosen set of files
  # 

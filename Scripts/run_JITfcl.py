#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess
from datetime import datetime
import shlex

# Function: Exit with error.
def exit_abnormal():
    usage()
    sys.exit(1)

# Function: Print a help message.
def usage():
    print("Usage: script_name.py [--copy_input_mdh --copy_input_ifdh]")
    print("e.g. run_JITfcl.py --copy_input_mdh")

# Function to run a shell command and return the output
def run_command(command):
    print(f"Running: {command}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running command: {command}")
        print(result.stderr)
        print(result.stdout)
        exit_abnormal()
    print(result.stdout)
    return result.stdout

def main():
    parser = argparse.ArgumentParser(description="Process some inputs.")
    parser.add_argument("--copy_input_mdh", action="store_true", help="Copy input files using mdh")
    parser.add_argument("--copy_input_ifdh", action="store_true", help="Copy input files using ifhd")
    args = parser.parse_args()
    copy_input_mdh = args.copy_input_mdh
    copy_input_ifdh = args.copy_input_ifdh
    
    fname = os.getenv("fname")
    if not fname:
        print("Error: fname environment variable is not set.")
        exit_abnormal()

    print(f"{datetime.now()} starting fclless submission")
    print(f"args: {sys.argv}")
    print(f"fname={fname}")
    print(f"pwd={os.getcwd()}")
    print("ls of default dir")
    run_command("ls -al")

    CONDOR_DIR_INPUT = os.getenv("CONDOR_DIR_INPUT", ".")
    run_command(f"ls -ltr {CONDOR_DIR_INPUT}")

    try:
        IND = int(fname.split('.')[4].lstrip('0') or '0')
    except (IndexError, ValueError) as e:
        print("Error: Unable to extract index from filename.")
        exit_abnormal()

    TARF = run_command(f"ls {CONDOR_DIR_INPUT}/*.tar").strip()
    print(f"IND={IND} TARF={TARF}")

    FCL = os.path.basename(TARF)[:-6] + f".{IND}.fcl"

    run_command(f"httokendecode -H")
    run_command(f"LV=$(which voms-proxy-init); echo $LV; ldd $LV; rpm -q -a | egrep 'voms|ssl'; printenv PATH; printenv LD_LIBRARY_PATH")
#    run_command(f"voms-proxy-info -all")


    if copy_input_mdh:
        run_command(f"mu2ejobfcl --jobdef {TARF} --index {IND} --default-proto file --default-loc dir:{os.getcwd()}/indir > {FCL}")
        infiles = run_command(f"mu2ejobiodetail --jobdef {TARF} --index {IND} --inputs")
        print("infiles: %s"%infiles)
        run_command(f"mdh copy-file -e 3 -o -v -s tape -l local {infiles}")
        run_command(f"mkdir indir; mv *.art indir/")
    elif copy_input_ifdh:
        run_command(f"mu2ejobfcl --jobdef {TARF} --index {IND} --default-proto file --default-loc dir:{os.getcwd()}/indir > {FCL}")
        infiles = run_command(f"mu2ejobiodetail --jobdef {TARF} --index {IND} --inputs| tee /dev/tty | mdh print-url -s root -")
        infiles = infiles.split()
        for f in infiles:
            run_command(f"ifdh cp {f} .")
        run_command(f"mkdir indir; mv *.art indir/")
    else:
        run_command(f"mu2ejobfcl --jobdef {TARF} --index {IND} --default-proto root --default-loc tape > {FCL}")

    print(f"{datetime.now()} submit_fclless {FCL} content")
    with open(FCL, 'r') as f:
        print(f.read())
    run_command(f"loggedMu2e.sh -c {FCL}")

if __name__ == "__main__":
    main()

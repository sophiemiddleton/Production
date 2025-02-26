#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess
from datetime import datetime
from pathlib import Path
import textwrap
import glob

# Function: Exit with error.
def exit_abnormal():
    usage()
    sys.exit(1)

# Function: Print a help message.
def usage():
    print("Usage: script_name.py [--copy_input_mdh --copy_input_ifdh]")
    print("e.g. run_JITfcl.py --copy_input_mdh")

# Function to run a shell command and return the output while streaming
def run_command(command):
    print(f"Running: {command}")
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    output = []  # Collect the command output
    for line in process.stdout:
        print(line, end="")  # Print each line in real-time
        output.append(line.strip())  # Collect the output lines
    process.wait()  # Wait for the command to complete

    if process.returncode != 0:
        print(f"Error running command: {command}")
        for line in process.stderr:
            print(line, end="")
        exit_abnormal()

    return "\n".join(output)  # Return the full output as a string

# Replace the first and last fields
def replace_file_extensions(input_str, first_field, last_field):
    fields = input_str.split('.')
    fields[0] = first_field
    fields[-1] = last_field
    return '.'.join(fields)

def main():
    parser = argparse.ArgumentParser(description="Process some inputs.")
    parser.add_argument("--copy_input_mdh", action="store_true", help="Copy input files using mdh")
    parser.add_argument("--copy_input_ifdh", action="store_true", help="Copy input files using ifhd")
    parser.add_argument('--dry-run', action='store_true', help='Print commands without actually running pushOutput')
    parser.add_argument('--test-run', action='store_true', help='Run 10 events only')
    parser.add_argument('--save-root', action='store_true', help='Save root and art output files')        
    parser.add_argument('--location', type=str, default='tape', help='Location identifier to include in output.txt (default: "tape")')    
    
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

    #unset BEARER_TOKEN
    print(f"BEARER_TOKEN before unset: {os.environ.get('BEARER_TOKEN')}")
    os.environ.pop('BEARER_TOKEN', None)
    # Check if the variable is unset
    print(f"BEARER_TOKEN after unset: {os.environ.get('BEARER_TOKEN')}")

    infiles = run_command(f"mu2ejobiodetail --jobdef {TARF} --index {IND} --inputs")
    if copy_input_mdh:
        run_command(f"mu2ejobfcl --jobdef {TARF} --index {IND} --default-proto file --default-loc dir:{os.getcwd()}/indir > {FCL}")
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

    if args.test_run:
        run_command(f"loggedMu2e.sh -n 10 -c {FCL}")
    else:
        run_command(f"loggedMu2e.sh -c {FCL}")

    run_command(f"ls {fname}")

    if args.save_root:
        out_fnames = glob.glob("*.art") + glob.glob("*.root")
    else:
        out_fnames = glob.glob("*.art")  # Find all .art files

    # Write the list to the file in one line
    parents = infiles.split() + [fname]  # Add {fname} to the list of files
    Path("parents_list.txt").write_text("\n".join(parents) + "\n")

    tbz_file = replace_file_extensions(FCL, "bck", "tbz")
    out_content = f"{args.location} {tbz_file} parents_list.txt\n"
    for out_fname in out_fnames:
        out_content += f"{args.location} {out_fname} parents_list.txt\n"
    Path("output.txt").write_text(out_content)

    # Push output
    run_command(f"httokendecode -H")
    if args.dry_run:
        print("[DRY RUN] Would run: pushOutput output.txt")
    else:
        run_command("pushOutput output.txt")

if __name__ == "__main__":
    main()

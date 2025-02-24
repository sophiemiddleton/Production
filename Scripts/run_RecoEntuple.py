#!/usr/bin/env python3
import re
import os
import sys
import logging
import argparse
from pathlib import Path
import subprocess
import textwrap
import hashlib

# ---------------------------------------------------
# Configure Logging to stdout
# ---------------------------------------------------
logger = logging.getLogger()
logger.handlers = []
logger.setLevel(logging.INFO)

handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Process digi files with specified MDC release')
    parser.add_argument('--stage-type', required=True,
                        help='Stage type (e.g., dig, mcs, nts)')
    parser.add_argument('--release', required=False,
                        help='Output MDC2020 version (e.g., an)')
    parser.add_argument('--ntuple', required=False,
                        help='Ntuple version (e.g., a)')
    parser.add_argument('--dbpurpose', required=False,
                        help='db purpose (e.g., best, perfect)')
    parser.add_argument('--dbversion', required=False,
                        help='db version (e.g., v1_3)')
    parser.add_argument('--digitype', required=False,
                        help='OnSpill, OffSpill')
    parser.add_argument('--fcl', required=True,
                        help='fcl template')
    parser.add_argument('--user', required=False, default="mu2e",
                        help='i.e. mu2e')
    parser.add_argument('--nevents', type=int, default=-1,
                        help='Number of events to process (default: -1)')
    parser.add_argument('--location', type=str, default='tape',
                        help='Location identifier to include in output.txt (default: "tape")')
    parser.add_argument('--dry-run', action='store_true',
                        help='Print commands without actually running them')
    return parser.parse_args()

def run_command(command: str) -> None:
    logging.info(f"Running: {command}")
    process = subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    
    # Stream the output line-by-line
    while True:
        line = process.stdout.readline()
        if not line:
            break
        logging.info(line.rstrip())
    
    process.stdout.close()
    process.wait()
    
    if process.returncode != 0:
        logging.error(f"Error running command: {command}")
        sys.exit(1)


def write_fcl_file(fname: str, args) -> tuple[str, list]:
    """Write FCL configuration file"""

    #start from the input name
    out_fname = os.path.basename(fname)

    if args.release:
        # Replace the portion after "MDC2020" up to the underscore or dot with the new release
        out_fname = re.sub(r'(MDC2020)[^_.]+', rf'\1{args.release}', out_fname)
    else:
        print("No release value specified. Filename remains unchanged.")
    
    print(f"write_fcl_file working on {out_fname}")
    
    # Read the FCL tempate file content
    with open(args.fcl, "r") as f:
        fcl_content = f.read()

    # Create random seed based on the input fname
    hash_object = hashlib.md5(out_fname.encode())
    hex_digest = hash_object.hexdigest()
    hash_int = int(hex_digest, 16)
    # Use modulo 2**63 to ensure the seed is in the valid range for a signed 64-bit integer.
    hash_int = hash_int % (2**63)
    
    out_fname_list = []
    if args.stage_type == "dig":

        for arg in ("digitype", "dbpurpose", "dbversion"):
            if not getattr(args, arg, None):
                print(f"Error: --{arg} argument is required for dig stage type.", file=sys.stderr)
                sys.exit(1)

        # output file will use dig file family
        out_fname = out_fname.replace("dts.", "dig.")
        #Cosmic needs a spcial epilog
        if "Cosmic" in out_fname:
            fcl_content += '#include "Production/JobConfig/digitize/cosmic_epilog.fcl"\n'
        parts = out_fname.split(".")
        out_fname_triggered = ".".join(
            [parts[0]] + [args.user] + [parts[2] + f"{args.digitype}Triggered", parts[3] + f"_{args.dbpurpose}_{args.dbversion}"] + parts[4:])
        out_fname_triggerable = ".".join(
            [parts[0]] + [args.user] + [parts[2] + f"{args.digitype}Triggerable", parts[3] + f"_{args.dbpurpose}_{args.dbversion}"] + parts[4:])
        fcl_content += f'outputs.TriggeredOutput.fileName: "{out_fname_triggered}"\n'
        fcl_content += f'outputs.TriggerableOutput.fileName: "{out_fname_triggerable}"\n'
        fcl_content += f'services.SeedService.baseSeed: "{hash_int}"\n'
        out_fname_list = [out_fname_triggered, out_fname_triggerable]
    elif args.stage_type == "mcs":
        # output file will use mcs file family
        out_fname = out_fname.replace("dig.", "mcs.")
        # Extract dbpurpose and dbversion
        pattern = r"(MDC2020)\w+_(best|perfect)_(v\d+_\d+)"
        match = re.search(pattern, fname)
        if not match:
            raise ValueError(f"Invalid filename format: {fname}")
        
        purpose = f"{match.group(1)}_{match.group(2)}"
        version = f"{match.group(3)}"
        # Use the same dbpurpose and dbversion as input dig file
        fcl_content += f'services.DbService.purpose: {purpose}\n'
        fcl_content += f'services.DbService.version: {version}\n'  
        fcl_content += f'outputs.Output.fileName: "{out_fname}"\n'
        out_fname_list = [out_fname]
    elif args.stage_type == "nts":

        if not getattr(args, "ntuple", None):
            print("Error: --ntuple argument is required for nts stage type.", file=sys.stderr)
            sys.exit(1)
        
        # output file will use nts file family and root extension 
        out_fname = out_fname.replace("mcs.", "nts.")
        out_fname = out_fname.replace(".art", ".root")

        fields = out_fname.split('.')
        fields[3] += f"_{args.ntuple}"  # Append _a to the 4th field (index 3)
        out_fname = ".".join(fields)
        
        fcl_content += f'services.TFileService.fileName: "{out_fname}"\n'
        out_fname_list = [out_fname]

    elif args.stage_type == "dts":

        fcl_content += f'outputs.CopyOutput.fileName : "{out_fname}"\n'
        out_fname_list = [out_fname]


    else:
        print("Unknown stage type")
        sys.exit(1)
    
    #Create fcl filename
    split_name = out_fname_list[0].split('.')
    split_name[0] = "cnf"
    split_name[-1] = "fcl"
    fcl_file = '.'.join(split_name)

    #Write to fcl file
    with Path(fcl_file).open("w") as f:
        f.write(fcl_content)
        logging.info("FCL file created successfully")
        logging.info(f"FCL content:\n{fcl_content}")
    return str(fcl_file), out_fname_list

def main():
    # Parse command line arguments
    args = parse_args()
    
    # Get input filename
    in_fname = os.getenv("fname")
    if not in_fname:
        raise ValueError("fname environment variable not set")
    
    logging.info(f"Using output MDC2020 version: {args.stage_type}")
    
    # Write fcl configuration
    fcl_file, out_fname_list = write_fcl_file(in_fname, args)
    print("Filelist: %s"%out_fname_list)
    
    # Run processing
    nevents = args.nevents  # Number of events to process
    run_command(f"loggedMu2e.sh -n {nevents} -s {in_fname} -c {fcl_file}")
    
    # Handle parent files
    in_fname_base = os.path.basename(in_fname)
    Path(f"parents_{in_fname_base}").write_text(in_fname_base)

    #Create tarbar filename
    split_name = out_fname_list[0].split('.')
    split_name[0] = "bck"         # Replace first field
    split_name[-1] = "tbz"        # Replace last field
    tbz_file = '.'.join(split_name)

    out_content = ""
    for f in out_fname_list:
        out_content += f'{args.location} {f} parents_{in_fname_base}\n'
    out_content += f'{args.location} {tbz_file} parents_{in_fname_base}\n'
    Path("output.txt").write_text(out_content)
    
    # Push output
    if args.dry_run:
        logging.info(f"[DRY RUN] Would run: pushOutput output.txt")
    else:
        run_command("pushOutput output.txt")

if __name__ == "__main__":
    main()

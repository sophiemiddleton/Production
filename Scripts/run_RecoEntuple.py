#!/usr/bin/env python3
import re
import os
import sys
import logging
import argparse
from pathlib import Path
import subprocess
import textwrap

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
    parser.add_argument('--version_reco', required=True,
                        help='Output reco version (e.g., an)')
    parser.add_argument('--version_entpl', required=False, default="",
                        help='Output evntuple version (e.g., v06_01_00)')
    parser.add_argument('--nevents', type=int, default=-1,
                        help='Number of events to process (default: -1)')
    parser.add_argument('--location', type=str, default='tape',
                        help='Location identifier to include in output.txt (default: "tape")')
    parser.add_argument('--dry-run', action='store_true',
                        help='Print commands without actually running them')
    return parser.parse_args()

def run_command(command: str) -> str:
    """Run shell command and handle output"""
    logging.info(f"Running: {command}")
    result = subprocess.run(command, shell=True, check=False, capture_output=True, text=True)
    if result.stdout:
        logging.info(result.stdout)
    if result.returncode != 0:
        logging.error(f"Error running command: {command}")
        logging.error(result.stderr)
        sys.exit(1)
    return result.stdout

def process_filename(fname: str, version_reco: str, version_entpl: str) -> tuple[str, str, str]:
    # Process input filename to extract purpose and version information.
    out_fname = os.path.basename(fname)    
    # Replace any MDC2020xx pattern with version_reco
    pattern = r'(MDC2020[a-z]+)'
    if version_entpl:
        out_fname = re.sub(pattern, f"MDC2020{version_reco}_{version_entpl}", out_fname)
        out_fname = out_fname.replace("mcs.", "nts.")
        out_fname = out_fname.replace(".art", ".root")
    else:
        out_fname = re.sub(pattern, f"MDC2020{version_reco}", out_fname)
        out_fname = out_fname.replace("dig.", "mcs.")
    
    pattern = r"(MDC2020)\w+_(best|perfect)_(v\d+_\d+)"
    match = re.search(pattern, fname)
    if not match:
        raise ValueError(f"Invalid filename format: {fname}")
        
    purpose = f"{match.group(1)}_{match.group(2)}"
    version = f"{match.group(3)}"
    return out_fname, purpose, version

def write_fcl_file(out_fname: str, purpose: str, version: str) -> str:
    """Write FCL configuration file"""
    if "mcs" in out_fname:
        fcl_content = f"""\
        #include "Production/JobConfig/reco/Reco.fcl"
        #include "Production/JobConfig/reco/MakeSurfaceSteps.fcl"
        services.DbService.purpose: {purpose}
        services.DbService.version: {version}
        services.DbService.verbose : 2
        outputs.Output.fileName: "{out_fname}"
        """
    elif "nts" in out_fname:
        desc =  out_fname.split('.')[2]
        fcl_content = f"""\
        #include "EventNtuple/fcl/from_mcs-primary.fcl"
        services.TFileService.fileName: "{out_fname}"
        """
    else:
        sys.exit(1)
    
        
    # Remove leading indentation
    fcl_content = textwrap.dedent(fcl_content)
    
    
    #Create fcl filename
    split_name = out_fname.split('.')
    split_name[0] = "cnf"         # Replace first field
    split_name[-1] = "fcl"        # Replace last field
    fcl_file = '.'.join(split_name)

    #Write to fcl file
    with Path(fcl_file).open("w") as f:
        f.write(fcl_content)
        logging.info("FCL file created successfully")
        logging.info(f"FCL content:\n{fcl_content}")
    return str(fcl_file)

def main():
    try:
        # Parse command line arguments
        args = parse_args()
        
        # Get input filename
        in_fname = os.getenv("fname")
        if not in_fname:
            raise ValueError("fname environment variable not set")
        
        logging.info(f"Using output MDC2020 version: {args.version_reco}")
        
        # Process filename
        out_fname, purpose, version = process_filename(in_fname, args.version_reco, args.version_entpl)
        logging.info(f"Processing {in_fname} -> {out_fname}")
        
        # Write fcl configuration
        fcl_file = write_fcl_file(out_fname, purpose, version)
        
        # Run processing
        nevents = args.nevents  # Number of events to process
        run_command(f"loggedMu2e.sh -n {nevents} -s {in_fname} -c {fcl_file}")
        
        # Handle parent files
        in_fname_base = os.path.basename(in_fname)
        Path(f"parents_{in_fname_base}").write_text(in_fname_base)

        #Create tarbar filename
        split_name = out_fname.split('.')
        split_name[0] = "bck"         # Replace first field
        split_name[-1] = "tbz"        # Replace last field
        tbz_file = '.'.join(split_name)

        out_content = f"""\
        {args.location} {out_fname} parents_{in_fname_base}
        {args.location} {tbz_file} parents_{in_fname_base}
        """
        out_content = textwrap.dedent(out_content)        
        Path("output.txt").write_text(out_content)
                
        # Push output
        if args.dry_run:
            logging.info(f"[DRY RUN] Would run: pushOutput output.txt")
        else:
            run_command("pushOutput output.txt")
        
    except Exception as e:
        logging.error(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

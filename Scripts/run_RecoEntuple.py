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
import shutil

# ---------------------------------------------------
# Configure Logging to stdout (no timestamp or level)
# ---------------------------------------------------
logger = logging.getLogger()
logger.handlers = []
logger.setLevel(logging.INFO)

handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.INFO)
# Only print the message itself
formatter = logging.Formatter('%(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Process digi files with specified MDC release')
    parser.add_argument('--release', required=False,
                        help='Output MDC2020 version (e.g., an)')
    parser.add_argument('--dbpurpose', required=False,
                        help='db purpose (e.g., best, perfect)')
    parser.add_argument('--dbversion', required=False,
                        help='db version (e.g., v1_3)')
    parser.add_argument('--user', required=False, default="mu2e",
                        help='i.e. mu2e')
    parser.add_argument('--nevents', type=int, default=-1,
                        help='Number of events to process (default: -1)')
    parser.add_argument('--location', type=str, default='tape',
                        help='Location identifier to include in output.txt (default: "tape")')
    parser.add_argument('--dry-run', action='store_true',
                            help='Print commands without actually running them')
    parser.add_argument('--template-fcl', metavar='PATH', required=True,
                            help='Path to fcl template'
    )

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

def load_templates(template_path: str) -> list[str]:
    path = Path(template_path)
    if not path.is_file():
        logging.error(f"Template file not found: {path}")
        sys.exit(1)
    lines = [line.strip() for line in path.read_text().splitlines()]
    templates = [l for l in lines if l]
    if not templates:
        logging.error("No valid templates found in template-file")
        sys.exit(1)
    return templates

def write_fcl_file(input_fname: str, args) -> tuple[str, list[str]]:
    fcl_content = ""
    base_name = Path(input_fname).stem
    parts = base_name.split('.')
    if len(parts) < 5:
        logging.error(f"Filename '{base_name}' does not contain expected fields (desc, dsconf, sequence)")
        sys.exit(1)
    desc = parts[2]
    dsconf = parts[3]
    sequence = parts[4]

    #Extract dbpurpose and dbversion if available in filename
    m = re.search(r"\.MDC2020(?P<release>\w+)_(?P<dbpurpose>[^_]+)_(?P<dbversion>v\d+_\d+)\.",base_name)
    if m:
        dbpurpose = m.group("dbpurpose")  # 'best'
        dbversion = m.group("dbversion")  # 'v1_3'
        print("Extracted dbpurpose: %s, and dbversion: %s from a file"%(dbpurpose, dbversion))

    # Build formatting context
    ctx = {
        'user': args.user,
        'release': args.release,
        'desc': desc,
        'dsconf': dsconf,
        'sequence': sequence,
        'dbpurpose': dbpurpose or args.dbpurpose,
        'dbversion': dbversion or args.dbversion,
    }

    # Deterministic seed based on input filename
    hash_hex = hashlib.md5(input_fname.encode()).hexdigest()
    seed = int(hash_hex, 16) % (2**63)
    ctx['seed'] = seed

    templates = load_templates(args.template_fcl)
    out_files = []

    # Apply each template line
    for tpl in templates:
        try:
            line = tpl.format(**ctx)
            print(line)
        except KeyError as e:
            logging.error(f"Missing placeholder in template: {e}")
            sys.exit(1)
        fcl_content += line + "\n"
        # extract filename between quotes
        quote_match = re.search(r'"([^"]+)"', line)
        if quote_match:
            out_fname = quote_match.group(1)
            fields = out_fname.split('.')
            if len(fields) == 6: # Output must be in mu2e format: 6 fields
                out_files.append(fname)

    if not out_files:
        logging.error("No output filenames found in templates")
        sys.exit(1)

    # Derive FCL filename from first output
    first = out_files[0]
    print("first: %s", first)
    print("first: %s", out_files[1])
    cfg_name = Path(first).stem
    fcl_name = f"cnf.{cfg_name}.fcl"
    Path(fcl_name).write_text(fcl_content)
    logging.info(f"Written FCL: {fcl_name}")
    return fcl_name, out_files

def replace_file_fields(filename: str, first_field: str, last_field: str) -> str:
    parts = filename.split('.')
    if len(parts) < 4:
        raise ValueError(f"Expected at least 4 dot-separated fields, got {len(parts)}: {filename!r}")
    parts[3] = f"{parts[3]}-{parts[0]}"
    parts[0] = first_field
    parts[-1] = last_field

    return '.'.join(parts)

def main():
    # Parse command line arguments
    args = parse_args()
    
    # Get input filename
    in_fname = os.getenv("fname")
    if not in_fname:
        raise ValueError("fname environment variable not set")
    
    logging.info(f"Using output MDC2020 version")
    
    # Write fcl configuration
    fcl_file, out_fname_list = write_fcl_file(in_fname, args)
    print("Filelist: %s" % out_fname_list)
    
    # Run processing
    nevents = args.nevents  # Number of events to process
    run_command(f"mu2e -n {nevents} -s {in_fname} -c {fcl_file}")
    
    # Handle parent files
    in_fname_base = os.path.basename(in_fname)
    Path(f"parents_{in_fname_base}").write_text(in_fname_base)

    out_content = ""
    for f in out_fname_list:
        out_content += f'{args.location} {f} parents_{in_fname_base}\n'

    # In production mode, copy the job submission log file from jsb_tmp to LOGFILE_LOC.
    LOGFILE_LOC = replace_file_fields(fcl_file, first_field="log", last_field="log")

    # Copy the jobsub log if JSB_TMP is defined
    jsb_tmp = os.getenv("JSB_TMP")
    if jsb_tmp:
        jobsub_log = "JOBSUB_LOG_FILE"
        src = os.path.join(jsb_tmp, jobsub_log)
        print(f"Copying jobsub log from {src} to {LOGFILE_LOC}")
        shutil.copy(src, LOGFILE_LOC)

    out_content += f"disk {LOGFILE_LOC} parents_{in_fname_base}\n"
    Path("output.txt").write_text(out_content)
    
    # Push output
    if args.dry_run:
        logging.info(f"[DRY RUN] Would run: pushOutput output.txt")
    else:
        run_command("pushOutput output.txt")

    # Cleanup
    run_command("rm -f *.root *.art *.txt")
        
if __name__ == "__main__":
    main()

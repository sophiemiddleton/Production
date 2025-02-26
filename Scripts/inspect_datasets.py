#!/usr/bin/env python3
"""
Script to analyze datasets and save locality counts to pandas DataFrame
Run as:
mu2einit
muse setup ops
muse setup
inspect_datasets.py data/datasets_dig.txt
"""

import mdh_cli
import sys
import argparse
from collections import Counter
from io import StringIO
import contextlib
import pandas as pd
import re
import subprocess
import json
import os
from datetime import datetime

def analyze_dataset(cli, dataset, skip_dcache_status):

    counts = {}
    
    if not skip_dcache_status:
        try:
            # Run mdh query-dcache with online status
            output = StringIO()
            with contextlib.redirect_stdout(output):
                cli.run(['query-dcache', '-o', dataset])

            # Extract statuses from the output
            statuses = re.findall(r'(NEARLINE|ONLINE_AND_NEARLINE)', output.getvalue())
            counts = Counter(statuses)
        except RuntimeError as e:
            print ("Bad dataset - please fix")

    # Get file info including size and rse.nevent using metacat command
    try:

        cmd = f'metacat query -m all -j files from mu2e:{dataset}'
        print("cmd: %s"%cmd)
        metacat_output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, universal_newlines=True)
        file_list = json.loads(metacat_output)

        total_size_int = 0
        total_nevent = 0
        total_files = len(file_list)

        
        for file_info in file_list:
            # Sum up sizes
            size = file_info.get('size', 0)
            total_size_int += size

            # Sum up rse.nevent values
            metadata = file_info.get('metadata', {})
            nevent = metadata.get('rse.nevent', 0)
            total_nevent += nevent

    except subprocess.CalledProcessError as e:
        print(f"Error running metacat command for dataset '{dataset}': {e.output}")
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON output from metacat command for dataset '{dataset}': {e}")
    
    return {
        'dataset': dataset,
        'NEARLINE': counts.get('NEARLINE', 0) if not skip_dcache_status else None,
        'ONLINE_AND_NEARLINE': counts.get('ONLINE_AND_NEARLINE', 0) if not skip_dcache_status else None,
        'Total size': round(total_size_int / (1024 ** 3), 2),   # Convert bytes to GB
        'Total events': total_nevent,
        'Total files': total_files  # Include the total number of files
    }

def main():

    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Analyze datasets and save results to a pandas DataFrame.")
    parser.add_argument("--input-file", help="Input file containing dataset names")
    parser.add_argument("--output-csv-folder", default="/exp/mu2e/app/home/mu2epro/cron/datasetMon/csv", 
                        help="Path to the folder where output CSV files will be saved.")
    parser.add_argument("--output-html-folder", default="/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/datasetMon", 
                        help="Path to the folder where output HTML files will be saved.")
    parser.add_argument("--skip-dcache-status", action="store_true", help="Skip querying dCache status.")
    args = parser.parse_args()

    # Use args.input_file for input file
    input_file = args.input_file
    output_csv_folder = args.output_csv_folder
    output_html_folder = args.output_html_folder

    # Create MdhCli instance
    cli = mdh_cli.MdhCli()

    # Process each dataset
    results = []
    with open(input_file, 'r') as f:
        datasets = [line.strip() for line in f if line.strip() and not line.strip().startswith('#')]
        
    for dataset in datasets:
        result = analyze_dataset(cli, dataset, args.skip_dcache_status)
        results.append(result)
        print(result)

    # Get the current date in YYYY-MM-DD format
    current_date = datetime.now().strftime('%Y-%m-%d')

    # Create and display DataFrame
    df = pd.DataFrame(results)
    df = df.sort_values(by='dataset', ascending=True, ignore_index=True)
    # Add the current date as a new column to the DataFrame
    df['date'] = current_date
    print(df)

    # Derive HTML file name from input_file
    base_name = os.path.splitext(os.path.basename(input_file))[0]
    html_file = f"{base_name}_results.html"

    # Calculate the sum of columns
    sum_row = df.select_dtypes(include='number').sum()
    sum_row['dataset'] = 'TOTAL'
    df = pd.concat([df, sum_row.to_frame().T], ignore_index=True)

    df.to_html('%s/%s.html'%(output_html_folder, base_name), index=False)
    print(f"HTML file '{html_file}' has been created.")
    
    # Optionally save to CSV
    df.to_csv('%s/%s_%s.csv'%(output_csv_folder, base_name, current_date), index=False)

if __name__ == "__main__":
    main()

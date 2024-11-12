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
#import pandas as pd
import re
import subprocess
import json

def analyze_dataset(cli, dataset):

    # Run mdh query-dcache with online status
    output = StringIO()
    with contextlib.redirect_stdout(output):
        cli.run(['query-dcache', '-o', dataset])

    # Extract statuses from the output
    statuses = re.findall(r'(NEARLINE|ONLINE_AND_NEARLINE)', output.getvalue())
    counts = Counter(statuses)

    # Get file info including size and rse.nevent using metacat command
    try:
        cmd = [
            'metacat', 'query',
            '-m', 'all', '-j',
            'files', 'from', 'mu2e:' + dataset
        ]
        metacat_output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True)
        file_list = json.loads(metacat_output)

        total_size_int = 0
        total_rse_nevent = 0

        for file_info in file_list:
            # Sum up sizes
            size = file_info.get('size', 0)
            total_size_int += size

            # Sum up rse.nevent values
            metadata = file_info.get('metadata', {})
            rse_nevent = metadata.get('rse.nevent', 0)
            total_rse_nevent += rse_nevent

    except subprocess.CalledProcessError as e:
        print(f"Error running metacat command for dataset '{dataset}': {e.output}")
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON output from metacat command for dataset '{dataset}': {e}")
    
    return {
        'dataset': dataset,
        'NEARLINE': counts.get('NEARLINE', 0),
        'ONLINE_AND_NEARLINE': counts.get('ONLINE_AND_NEARLINE', 0),
        'Total size': total_size_int,
        'Total events': total_rse_nevent
    }

def main():
    # Get input file from command line
    if len(sys.argv) != 2:
        print("Usage: ./script.py input_file")
        sys.exit(1)
    input_file = sys.argv[1]

    # Create MdhCli instance
    cli = mdh_cli.MdhCli()

    # Process each dataset
    results = []
    with open(input_file, 'r') as f:
        datasets = [line.strip() for line in f if line.strip() and not line.strip().startswith('#')]
        
    for dataset in datasets:
        result = analyze_dataset(cli, dataset)
        results.append(result)
        print(result)
    # Create and display DataFrame
#    df = pd.DataFrame(results)
#    print(df)

    # Optionally save to CSV
    # df.to_csv('dataset_results.csv', index=False)

if __name__ == "__main__":
    main()

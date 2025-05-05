#!/usr/bin/env python3
"""
Process multiple Mu2e datasets listed in a text file, extract TimeReport (CPU/Real),
MemReport (VmPeak/VmHWM), and TrigReport (Events total/passed) from each dataset’s logs,
compute per‑dataset averages (with CPU and Real converted to hours) and maxima,
convert VmPeak and VmHWM mean and max to GB (assuming MemReport values are in MB),
calculate trigger efficiency (PassedEv/TotalEv), count total log files per dataset,
and produce a single HTML summary with one row per dataset.
Time columns use two decimals (hours), memory columns use one decimal (GB),
efficiency two decimals, file count as integer.
"""

import sys
import subprocess
import argparse
import re
import pandas as pd

# Regex patterns
TIMEREPORT_REGEX = r"TimeReport CPU = ([0-9]*\.?[0-9]+) Real = ([0-9]*\.?[0-9]+)"
MEMREPORT_REGEX  = r"MemReport\s+VmPeak\s*=\s*([0-9]*\.?[0-9]+)\s+VmHWM\s*=\s*([0-9]*\.?[0-9]+)"
TRIGREPORT_REGEX = r"TrigReport Events total = ([0-9]+) passed = ([0-9]+)"

SECONDS_PER_HOUR = 3600.0
MB_PER_GB = 1024.0  # MemReport values are in MB, convert to GB


def get_file_list(dataset):
    """Run `mu2eDatasetFileList` and return full paths for a dataset."""
    try:
        proc = subprocess.run(
            ["mu2eDatasetFileList", dataset],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] mu2eDatasetFileList failed for {dataset}: {e.stderr}", file=sys.stderr)
        return []
    return [line.strip() for line in proc.stdout.splitlines() if line.strip().startswith('/')]


def parse_file(fp, tim_pat, mem_pat, trig_pat):
    """Scan a log file for TimeReport, MemReport, and TrigReport."""
    """Always returns the last match in the file."""
    cpu_s = real_s = vmp = vmh = total = passed = None
    try:
        with open(fp) as f:
            for line in f:
                m = tim_pat.search(line)
                if m:
                    cpu_s, real_s = float(m.group(1)), float(m.group(2))
                m2 = mem_pat.search(line)
                if m2:
                    vmp, vmh = float(m2.group(1)), float(m2.group(2))
                m3 = trig_pat.search(line)
                if m3:
                    total, passed = int(m3.group(1)), int(m3.group(2))
                                    
    except Exception as e:
        print(f"[WARN] could not read {fp}: {e}", file=sys.stderr)
    return cpu_s, real_s, vmp, vmh, total, passed


def collect_metrics_for_dataset(dataset):
    """Extract metrics from all logs of a dataset into a DataFrame."""
    files = get_file_list(dataset)
    if not files:
        return pd.DataFrame(columns=[
            'dataset','CPU','Real','VmPeak','VmHWM','TotalEv','PassedEv'
        ]), 0
    tim_pat = re.compile(TIMEREPORT_REGEX)
    mem_pat = re.compile(MEMREPORT_REGEX)
    trig_pat = re.compile(TRIGREPORT_REGEX)
    print(trig_pat)
    rows = []
    for fp in files:
        cpu_s, real_s, vmp, vmh, total, passed = parse_file(fp, tim_pat, mem_pat, trig_pat)

        if cpu_s is None and vmp is None and total is None:
            continue
        cpu  = cpu_s / SECONDS_PER_HOUR if cpu_s is not None else None
        real = real_s / SECONDS_PER_HOUR if real_s is not None else None
        rows.append({
            'dataset':   dataset,
            'CPU':       cpu,
            'Real':      real,
            'VmPeak':    vmp,
            'VmHWM':     vmh,
            'TotalEv':   total,
            'PassedEv':  passed
        })
    return pd.DataFrame(rows), len(files)


def write_html_report(df, html_path, fmt):
    """Write HTML summary report."""
    table = df.to_html(index=False, formatters=fmt)
    html = f"""
<!DOCTYPE html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <title>Mu2e Summary</title>
  <style>
    body {{font-family:sans-serif;margin:2em}}
    table {{border-collapse:collapse;width:90%}}
    th, td {{border:1px solid #888;padding:0.5em;text-align:right}}
    th {{background:#eee}}
    th:first-child, td:first-child {{text-align:left}}
  </style>
</head>
<body>
  <h1>Mu2e Time, Memory & Trigger Summary</h1>
  {table}
</body>
</html>"""
    with open(html_path, 'w') as f:
        f.write(html)
    print(f"[INFO] HTML written to {html_path}", file=sys.stderr)


def main():
    p = argparse.ArgumentParser(description="Summarize Mu2e logs across datasets")
    p.add_argument('-l','--list-file', required=True, help="File listing datasets")
    p.add_argument('-H','--html-output', default="summary.html", help="HTML output path")
    args = p.parse_args()
    try:
        with open(args.list_file) as lf:
            datasets = [ln.strip() for ln in lf if ln.strip() and not ln.startswith('#')]
    except Exception as e:
        print(f"[ERROR] reading list file: {e}", file=sys.stderr)
        sys.exit(1)
    all_dfs = []
    file_counts = {}
    for ds in datasets:
        print(f"Processing {ds}", file=sys.stderr)
        df, count = collect_metrics_for_dataset(ds)
        file_counts[ds] = count
        if not df.empty:
            all_dfs.append(df)
    if not all_dfs:
        print("No data", file=sys.stderr)
        sys.exit(1)
    combined = pd.concat(all_dfs, ignore_index=True)

    # Compute aggregated metrics
    summary = combined.groupby('dataset', as_index=False).agg(**{
        'CPU [h]':          ('CPU',     'mean'),
        'CPU_max [h]':      ('CPU',     'max'),
        'Real [h]':         ('Real',    'mean'),
        'Real_max [h]':     ('Real',    'max'),
        'VmPeak [GB]':      ('VmPeak',  lambda s: s.mean()/MB_PER_GB),
        'VmPeak_max [GB]':  ('VmPeak',  lambda s: s.max()/MB_PER_GB),
        'VmHWM [GB]':       ('VmHWM',   lambda s: s.mean()/MB_PER_GB),
        'VmHWM_max [GB]':   ('VmHWM',   lambda s: s.max()/MB_PER_GB),
        'TotalEv':          ('TotalEv','mean'),
        'PassedEv':         ('PassedEv','mean'),
    })

    # Add file count and efficiency
    summary['Files'] = summary['dataset'].map(file_counts)
    summary['Efficiency'] = summary['PassedEv'] / summary['TotalEv']

    # Formatting rules
    fmt = {
        'CPU [h]':         lambda x: f"{x:.2f}",
        'CPU_max [h]':     lambda x: f"{x:.2f}",
        'Real [h]':        lambda x: f"{x:.2f}",
        'Real_max [h]':    lambda x: f"{x:.2f}",
        'VmPeak [GB]':     lambda x: f"{x:.1f}",
        'VmPeak_max [GB]': lambda x: f"{x:.1f}",
        'VmHWM [GB]':      lambda x: f"{x:.1f}",
        'VmHWM_max [GB]':  lambda x: f"{x:.1f}",
        'TotalEv':         lambda x: f"{int(x)}",
        'PassedEv':        lambda x: f"{int(x)}",
        'Files':           lambda x: f"{int(x)}",
        'Efficiency':      lambda x: f"{x:.2f}",
    }

    # Output
    print(summary.to_string(index=False, formatters=fmt))
    write_html_report(summary, args.html_output, fmt)

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Wrapper to print or execute gen_Mix.sh for every combination defined
in a JSON config where every top‑level key is treated as a list of values.

Example JSON:
{
    "mver": ["p"],
    "over": ["au"],
    "primary_dataset": [
        "dts.mu2e.NoPrimary.MDC2020ar.art",
        "dts.mu2e.PbarSTGun.MDC2020ar.art",
        "dts.mu2e.RMCFlatGammaResampling.MDC2020ar.art"
    ],
    "dbpurpose": ["perfect", "best"],
    "pbeam": ["Mix1BB", "Mix2BB"]
}
"""
import argparse
import json
import itertools
import subprocess
import sys
import shlex
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--json", required=True,
        help="Path to JSON configuration"
    )
    parser.add_argument(
        "--dry-run", action="store_true", dest="dry_run",
        help="Print commands without executing gen_Mix.sh"
    )
    parser.add_argument(
        "--pushout", action="store_true", dest="pushout",
        help="Pass --pushout through to gen_Mix.sh"
    )
    args = parser.parse_args()

    # Load JSON config
    cfg_path = Path(args.json)
    with cfg_path.open() as f:
        cfg = json.load(f)
    if not isinstance(cfg, dict):
        print("Error: JSON root must be an object", file=sys.stderr)
        sys.exit(1)

    # Keys to iterate over
    keys = list(cfg.keys())

    # Loop over Cartesian product of all keys
    for combo in itertools.product(*(cfg[k] for k in keys)):
        params = dict(zip(keys, combo))

        # Build gen_Mix.sh command
        cmd = ["/exp/mu2e/app/users/oksuzian/muse_080224/Production/Scripts/gen_Mix.sh"]
        for key, val in params.items():
            cmd += [f"--{key}", str(val)]
        if args.pushout:
            cmd.append("--pushout")

        # Print command
        print("\n>>>", " ".join(shlex.quote(a) for a in cmd))

        if not args.dry_run:
            subprocess.run(cmd, check=True)

if __name__ == "__main__":
    main()

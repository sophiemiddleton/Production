#!/usr/bin/env python3
"""
The livetime an ensemble (SamplingInput) campaign actually built, from its job logs.

make_template_fcl.py turns the requested on-spill time L_req into a sampled-event
target T (a Poisson draw around the sum of the expected dts yields) and one weight
per process, w_i = E_i / T. The campaign represents L_req only if all T events are
sampled. Jobs end when an input runs out, and some jobs fail or are never run, so the
ensemble that was built holds N events, not T. Its livetime is

    L_true = L_req * N / T

N is the sum of the SamplingInput tables in the logs (one per job; a job that ran
twice is counted once), or the dts dataset's event count in SAM with --sam.

Each process also gives its own estimate, L_i = L_req * N_i / E_i (+- L_i/sqrt(N_i)),
where E_i is its expected dts yield. These should agree with L_true within errors; a
process far away means its inputs or weight are off, not that the livetime is.
The same scale factor N/T applies to the total (on + off spill) livetime, POT and
muon stops, which are printed when the manifest has them.

Inputs: the job logs (--logs, or --from-csv for the CSV written by
plot_ensemble_validation.py / mds.sh validate) and either
  --manifest <workdir>/manifest.env   (mds.sh; onspilltime, sample_target, dts_expected_*)
or, for tags made with the Stage scripts,
  --livetime L_req  with  --target T, --stage2-log <make_template_fcl.py output>
                          or --expected LABEL=E_i ...
Without T, it is recovered from the weights in the logs as sum(E_i) / sum(w_i).

e.g.
  ensemble_livetime.py --logs /pnfs/mu2e/persistent/datasets/phy-etc/log/mu2e/ensemble/MDC2025ax_MDS4a/log \\
      --manifest MDS4a/manifest.env --sam
  ensemble_livetime.py --from-csv validate.csv --livetime 5.72e6 --stage2-log stage2.out

--env also prints the results as KEY="VALUE" lines (true_onspilltime, ...) for the manifest.
Needs numpy (via plot_ensemble_validation.py, which must sit next to this script).
"""

import argparse
import math
import os
import re
import shlex
import subprocess
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plot_ensemble_validation import read_csv, read_logs, read_stage2  # noqa: E402


def read_manifest(path):
    """KEY="VALUE" lines of an mds.sh manifest.env, unquoted."""
    m = {}
    with open(path) as f:
        for line in f:
            k, sep, v = line.strip().partition("=")
            if sep and re.fullmatch(r"[A-Za-z_]\w*", k):
                try:
                    m[k] = shlex.split(v)[0] if v else ""
                except (ValueError, IndexError):
                    m[k] = v.strip('"')
    return m


def sam_event_count(dataset):
    """Total event count of a SAM dataset, or None if samweb is not available."""
    try:
        out = subprocess.run(["samweb", "list-files", "--summary", "dh.dataset=%s" % dataset],
                             capture_output=True, text=True, check=True, timeout=300).stdout
    except (OSError, subprocess.SubprocessError) as e:
        print("WARNING: samweb summary of %s failed: %s" % (dataset, e), file=sys.stderr)
        return None, None
    nev = re.search(r"Event count:\s*(\d+)", out)
    nf = re.search(r"File count:\s*(\d+)", out)
    return (int(nev.group(1)) if nev else None), (int(nf.group(1)) if nf else None)


def fnum(x):
    return float(x) if x not in (None, "", "?") else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--logs", help="directory of ensemble job logs (searched recursively)")
    src.add_argument("--from-csv", help="per-job CSV written by plot_ensemble_validation.py (validate.csv)")
    ap.add_argument("--manifest", help="mds.sh manifest.env: requested livetime, target and expected yields")
    ap.add_argument("--livetime", type=float, help="requested on-spill livetime L_req [s] (overrides the manifest)")
    ap.add_argument("--target", type=float, help="sampled-event target T, make_template's GENERATING")
    ap.add_argument("--stage2-log", help="saved make_template_fcl.py output with EXPECTED EVENTS lines")
    ap.add_argument("--expected", action="append", default=[], metavar="LABEL=N",
                    help="expected dts yield of one process (overrides the manifest and --stage2-log)")
    ap.add_argument("--duty-factor", type=float, help="on-spill / total livetime (default: the manifest's)")
    ap.add_argument("--npot", type=float, help="POT of the requested livetime (default: the manifest's beam_npot)")
    ap.add_argument("--njobs", type=int, help="jobs the campaign defines (default: the manifest's jobdef_njobs)")
    sam = ap.add_mutually_exclusive_group()
    sam.add_argument("--sam", nargs="?", const="", metavar="DATASET",
                     help="take N from the dts dataset's event count in SAM (default dataset: the manifest's ds_dts)")
    sam.add_argument("--sam-events", type=int, help="take N as this many events (e.g. a SAM count made elsewhere)")
    ap.add_argument("--env", action="store_true", help="also print the results as KEY=\"VALUE\" lines")
    ap.add_argument("-j", type=int, default=8, help="parallel log readers")
    args = ap.parse_args()

    man = read_manifest(args.manifest) if args.manifest else {}
    lreq = args.livetime or fnum(man.get("onspilltime"))
    if not lreq:
        sys.exit("no requested livetime: pass --livetime, or --manifest with onspilltime")
    expected, target = {}, fnum(man.get("sample_target"))
    for k, v in man.items():
        if k.startswith("dts_expected_") and fnum(v):
            expected[k[len("dts_expected_"):]] = float(v)
    if args.stage2_log:
        e2, t2 = read_stage2(args.stage2_log)
        expected.update(e2)
        target = t2 or target
    for e in args.expected:
        k, _, v = e.partition("=")
        expected[k] = float(v)
    target = args.target or target
    duty = args.duty_factor or fnum(man.get("duty_factor"))
    npot = args.npot or fnum(man.get("beam_npot")) or fnum(man.get("beam_pot"))
    nmot = fnum(man.get("beam_nmot"))
    njobs = args.njobs or (int(man["jobdef_njobs"]) if man.get("jobdef_njobs", "").isdigit() else None)

    # ---------------- what the logs say was sampled
    bad = []
    if args.logs:
        rows, bad = read_logs(args.logs, args.j)
    else:
        rows = read_csv(args.from_csv)
    if not rows:
        sys.exit("no SamplingInput tables found")
    # a job that ran more than once (a resubmission) made the same file; count it once
    # (a log whose name has no job number is its own job)
    tables = defaultdict(dict)
    for r in rows:
        tables[(r["job"] if r["job"] >= 0 else r["log"], r["log"])][r["dataset"]] = r
    logs_of = defaultdict(list)
    for job, log in sorted(tables, key=str):
        logs_of[job].append(log)
    per_job = {job: tables[(job, ls[0])] for job, ls in logs_of.items()}
    dup = {j: ls for j, ls in logs_of.items() if len(ls) > 1}
    labels = sorted({d for t in per_job.values() for d in t})
    counts = {l: sum(t[l]["counts"] for t in per_job.values() if l in t) for l in labels}
    weights = {}
    for t in per_job.values():
        for l, r in t.items():
            weights.setdefault(l, r["weight"])
    n_logs = sum(counts.values())

    if not target:
        if expected and set(labels) <= set(expected):
            # w_i = E_i / T for every process, so T = sum(E) / sum(w)
            target = sum(expected[l] for l in labels) / sum(weights[l] for l in labels)
            target_src = "sum(E_i) / sum(w_i) from the log weights"
        else:
            sys.exit("no sampled-event target: pass --target, --stage2-log, --expected for every process, "
                     "or --manifest with sample_target")
    else:
        target_src = "make_template_fcl.py (GENERATING)"

    n, n_src = n_logs, "SamplingInput tables in %d job logs" % len(per_job)
    sam_n = sam_files = None
    if args.sam_events is not None:
        sam_n = args.sam_events
    elif args.sam is not None:
        ds = args.sam or man.get("ds_dts")
        if not ds:
            sys.exit("--sam needs a dataset name, or --manifest with ds_dts")
        sam_n, sam_files = sam_event_count(ds)
    if sam_n is not None:
        n, n_src = sam_n, "dts dataset in SAM" + (" (%d files)" % sam_files if sam_files is not None else "")

    frac = n / target
    ltrue = lreq * frac

    # ---------------- report
    print("\n══ Ensemble livetime: built vs requested ══")
    print("jobs with a table: %d" % len(per_job) + ("   of %d defined" % njobs if njobs else "")
          + "   logs without one: %d" % len(bad) + "   jobs logged more than once: %d" % len(dup))
    for b in bad[:10]:
        print("   no table: %s" % b)
    for j in sorted(dup, key=str)[:10]:
        print("   job %s counted once, logs: %s" % (j, " ".join(os.path.basename(p) for p in dup[j])))
    if sam_n is not None:
        print("events in the logs: %d   in SAM: %d   (SAM - logs: %+d)" % (n_logs, sam_n, sam_n - n_logs))
        if sam_n != n_logs:
            print("   WARNING: the logs and SAM disagree; SAM is what was delivered, so it is used")

    print("\nrequested on-spill livetime L_req   %14.6g s" % lreq)
    print("sampled-event target T              %14.0f   (%s)" % (target, target_src))
    print("events built N                      %14d   (%s)" % (n, n_src))
    print("fraction built N / T                %14.6f" % frac)
    print("TRUE on-spill livetime L_req * N/T  %14.6g s   (%.2f days)" % (ltrue, ltrue / 86400))
    if duty:
        print("TRUE total livetime (/ duty %.3f)   %14.6g s   (%.2f days)" % (duty, ltrue / duty, ltrue / duty / 86400))
    if npot:
        print("TRUE POT                            %14.4g" % (npot * frac))
    if nmot:
        print("TRUE stopped muons                  %14.4g" % (nmot * frac))

    have = [l for l in labels if l in expected]
    est = {}
    if have:
        print("\nper-process estimate  L_i = L_req * N_i / E_i   (logs; should agree with L_true)")
        print("%-26s %10s %12s %14s %10s %7s" % ("dataset", "sampled", "expected", "L_i [s]", "L_i/L_true", "pull"))
        for l in have:
            c, e = counts[l], expected[l]
            li = lreq * c / e
            sig = li / math.sqrt(c) if c else float("nan")
            est[l] = li
            print("%-26s %10d %12.0f %14.6g %10.4f %7.1f" % (l, c, e, li, li / ltrue, (li - ltrue) / sig if c else float("nan")))
        sum_e, sum_c = sum(expected[l] for l in have), sum(counts[l] for l in have)
        lyield = lreq * sum_c / sum_e
        print("%-26s %10d %12.0f %14.6g %10.4f   (+- %.2g s, Poisson)" % ("all (sum N_i / sum E_i)", sum_c, sum_e,
                                                                         lyield, lyield / ltrue, lyield / math.sqrt(sum_c)))
        if sam_n is not None and sam_n != n_logs:
            print("   (per-process estimates use the log counts; scale by %.6f for SAM)" % (sam_n / n_logs))
    missing = [l for l in labels if l not in expected]
    if missing:
        print("\n(no expected yield for %s: no per-process estimate)" % " ".join(missing))

    if args.env:
        print()
        out = [("true_events", n), ("true_fraction", "%.6f" % frac), ("true_onspilltime", "%.6g" % ltrue)]
        if duty:
            out.append(("true_beam_livetime", "%.6g" % (ltrue / duty)))
        if npot:
            out.append(("true_beam_npot", "%.4e" % (npot * frac)))
        if nmot:
            out.append(("true_beam_nmot", "%.4e" % (nmot * frac)))
        for k, v in out:
            print('%s="%s"' % (k, v))


if __name__ == "__main__":
    main()

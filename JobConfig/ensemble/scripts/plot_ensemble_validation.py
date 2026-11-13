#!/usr/bin/env python3
"""
Validation plots for an ensemble (SamplingInput) campaign, made from the job logs.

Each job log has a SamplingInput table: per dataset the sampled count, the
sampled and expected fractions, the weight, and the next event or
"(no more available)" for the input that ran out and ended the job.

Pages written to <out>.pdf:
  1. per-process sampled fraction over all jobs vs the configured fraction (pull)
  2. per-job sampled fraction, with the weight from the .fcl (--fcl, or as printed in the logs)
  3. per-job pulls, which should be unit Gaussians
  4. events per job, and which input ran out to end each job
  5. events per job vs job index (spots bad or short input files)
  6. with expected dts yields: sampled vs expected per process, and the total
     vs the target, i.e. the fraction of the requested livetime achieved

The expected dts yields are what make_template_fcl.py prints in Stage 2:
  NORM <generated> RECO <dts entries> GEN <generated> EXPECTED EVENTS: <dts expected>
They include the dts filter efficiency (RECO/GEN); the Stage 1 yields in
<TAG>.txt do not. Pass the saved Stage 2 output with --stage2-log, or give
them by hand with --expected LABEL=N.

e.g.
  plot_ensemble_validation.py \\
    --logs /pnfs/mu2e/persistent/datasets/phy-etc/log/mu2e/ensemble/MDC2025ax_MDS4a/log \\
    --stage2-log stage2.out --out MDS4a_validation
  plot_ensemble_validation.py --from-csv MDS4a_validation.csv --out MDS4a_validation

--check prints PASS/FAIL after the tables and exits 1 on FAIL. It fails when
  - a process's fraction over all jobs is more than --nsigma from its weight
  - logs have no SamplingInput table, or there are fewer jobs than --njobs
  - (with expected yields) a process is more than --nsigma Poisson sigmas from
    its expected dts yield, or the total is more than --nsigma from the target
and warns when the per-job pull RMS is far from 1 or an input other than the
usual limiting one ends more than 1% of jobs.

Needs numpy; the PDF also needs matplotlib (e.g. the Mu2e ana environment's
python3). --no-plots skips the PDF.
"""

import argparse
import csv
import math
import os
import re
import sys
from collections import Counter, defaultdict
from multiprocessing import Pool

import numpy as np

# one data hue, a neutral for references, red only for flags
DATA = "#2a78d6"
REF = "#52514e"
FLAG = "#e34948"
GRID = "#e4e3df"

RC = {
    "axes.edgecolor": REF, "axes.labelcolor": "#0b0b0b", "axes.titlesize": 10,
    "axes.labelsize": 9, "xtick.labelsize": 8, "ytick.labelsize": 8, "xtick.color": REF,
    "ytick.color": REF, "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6,
    "axes.axisbelow": True, "axes.spines.top": False, "axes.spines.right": False,
    "legend.fontsize": 7, "legend.frameon": False, "figure.dpi": 110,
}

HEADER = re.compile(r"^Dataset +Counts ")
JOBID = re.compile(r"\.(\d+)-\d+\.log$")
NUM = re.compile(r"^[0-9]+(\.[0-9]*)?([eE][-+]?[0-9]+)?$")
FIELDS = ["job", "dataset", "counts", "frac_sampled", "frac_expected", "weight", "exhausted", "log"]


def parse_log(path):
    """Rows of the last SamplingInput table in one log; [] if it has none."""
    rows, table, inb = [], [], False
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if HEADER.match(line):
                    inb, table = True, []
                    continue
                if not inb:
                    continue
                if line.startswith("Total"):
                    inb, rows = False, table
                    continue
                tok = line.split()
                # name  counts  frac_sampled  |  frac_expected  weight  next...
                if len(tok) >= 6 and tok[3] == "|" and NUM.match(tok[1]):
                    table.append((tok[0], int(tok[1]), float(tok[2]), float(tok[4]),
                                  float(tok[5]), "no more available" in line))
    except OSError as e:
        print("WARNING: cannot read %s: %s" % (path, e), file=sys.stderr)
    m = JOBID.search(path)
    job = int(m.group(1)) if m else -1
    return [dict(zip(FIELDS, (job,) + r + (path,))) for r in rows] or [{"job": job, "log": path}]


def read_logs(logdir, nproc):
    paths = sorted(os.path.join(d, f) for d, _, fs in os.walk(logdir, followlinks=True)
                   for f in fs if f.endswith(".log"))
    if not paths:
        sys.exit("no .log files under %s" % logdir)
    print("parsing %d logs in %s ..." % (len(paths), logdir))
    with Pool(nproc) as pool:
        per_log = pool.map(parse_log, paths, chunksize=20)
    rows = [r for rs in per_log for r in rs if "dataset" in r]
    bad = [rs[0]["log"] for rs in per_log if "dataset" not in rs[0]]
    return rows, bad


def write_csv(rows, path):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print("wrote %s" % path)


def read_csv(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append({"job": int(r["job"]), "dataset": r["dataset"], "counts": int(r["counts"]),
                         "frac_sampled": float(r["frac_sampled"]), "frac_expected": float(r["frac_expected"]),
                         "weight": float(r["weight"]), "exhausted": r["exhausted"] == "True", "log": r["log"]})
    return rows


def read_stage2(path):
    """Expected dts yields (and the sampled target, if printed) from make_template_fcl.py output."""
    expected, target, label = {}, None, None
    with open(path, errors="replace") as f:
        for line in f:
            s = line.strip()
            m = re.search(r"EXPECTED EVENTS:\s*(\S+)", s)
            if s.startswith("NORM") and m and label:
                expected[label] = float(m.group(1))
                label = None
            elif s.startswith("TOTAL EXPECTED EVENTS:"):
                m = re.search(r"GENERATING:\s*(\S+)", s)
                if m:
                    target = float(m.group(1))
            elif re.fullmatch(r"[A-Za-z0-9]+", s):
                label = s
    return expected, target


def read_fcl_weights(path):
    """dataset -> weight from the dataSets block of a SamplingInput .fcl."""
    weights, label = {}, None
    with open(path) as f:
        for line in f:
            m = re.match(r"\s*(\w+)\s*:\s*\{", line)
            if m:
                label = m.group(1)
            m = re.match(r"\s*weight\s*:\s*(\S+)", line)
            if m and label:
                weights[label] = float(m.group(1))
    if not weights:
        sys.exit("no dataset weights found in %s" % path)
    return weights


def grid(plt, n):
    ncol = 3
    nrow = math.ceil(n / ncol)
    fig, axes = plt.subplots(nrow, ncol, figsize=(11, 3.0 * nrow), squeeze=False)
    for ax in axes.flat[n:]:
        ax.set_visible(False)
    return fig, axes.flat


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--logs", help="directory of ensemble job logs (searched recursively)")
    src.add_argument("--from-csv", help="re-plot from a CSV written by an earlier run")
    ap.add_argument("--out", default="ensemble_validation", help="output prefix for .pdf and .csv")
    ap.add_argument("--stage2-log", help="saved Stage 2 / make_template_fcl.py output with EXPECTED EVENTS lines")
    ap.add_argument("--expected", action="append", default=[], metavar="LABEL=N",
                    help="expected dts yield for one process (overrides --stage2-log)")
    ap.add_argument("--fcl", help="SamplingInput .fcl to take the weights from (default: the weights in the logs)")
    ap.add_argument("--target", type=float, help="sampled-event target N (make_template's GENERATING); "
                    "default: the sum of the expected yields, if every process has one")
    ap.add_argument("--nsigma", type=float, default=5, help="flag pulls beyond this")
    ap.add_argument("--njobs", type=int, help="number of jobs the campaign ran; fewer logs fail --check")
    ap.add_argument("--check", action="store_true", help="print PASS/FAIL and exit 1 on FAIL")
    ap.add_argument("--no-plots", action="store_true", help="tables only, no PDF (no matplotlib needed)")
    ap.add_argument("-j", type=int, default=8, help="parallel log readers")
    args = ap.parse_args()

    bad = []
    if args.logs:
        rows, bad = read_logs(args.logs, args.j)
        write_csv(rows, args.out + ".csv")
    else:
        rows = read_csv(args.from_csv)
    if not rows:
        sys.exit("no SamplingInput tables found")

    expected, target = {}, None
    if args.stage2_log:
        expected, target = read_stage2(args.stage2_log)
        if not expected:
            print("WARNING: no EXPECTED EVENTS lines in %s" % args.stage2_log, file=sys.stderr)
    for e in args.expected:
        k, _, v = e.partition("=")
        expected[k] = float(v)
    target = args.target or target

    # per job and per dataset arrays
    jobs = sorted({r["job"] for r in rows})
    labels = sorted({r["dataset"] for r in rows})
    jidx = {j: i for i, j in enumerate(jobs)}
    counts = {l: np.zeros(len(jobs)) for l in labels}
    pexp = {l: np.zeros(len(jobs)) for l in labels}
    exhausted = {}
    for r in rows:
        i = jidx[r["job"]]
        counts[r["dataset"]][i] = r["counts"]
        pexp[r["dataset"]][i] = r["frac_expected"]
        if r["exhausted"]:
            exhausted.setdefault(r["job"], r["dataset"])
    if not target and expected and set(labels) <= set(expected):
        target = sum(expected[l] for l in labels)
    ntot = sum(counts.values())
    if args.fcl:
        fcl_w, fcl_src = read_fcl_weights(args.fcl), os.path.basename(args.fcl)
    else:
        fcl_w, fcl_src = {}, "the .fcl (as printed in the logs)"
        for r in rows:
            fcl_w.setdefault(r["dataset"], r["weight"])
    N = ntot.sum()

    fails, warns = [], []

    # ---------------- text summary
    print("\njobs with a table: %d   logs without one (failed?): %d   events: %d" % (len(jobs), len(bad), N))
    if bad:
        fails.append("%d logs have no SamplingInput table" % len(bad))
    if args.njobs and len(jobs) < args.njobs:
        fails.append("%d jobs with a table, the campaign has %d" % (len(jobs), args.njobs))
    for b in bad[:10]:
        print("   no table: %s" % b)
    print("\n%-26s %12s %10s %10s %7s %8s %8s" % ("dataset", "sampled", "frac", "expected", "pull", "job<pull>", "jobRMS"))
    summary = {}
    for l in labels:
        p = np.average(pexp[l], weights=ntot)
        pull = (counts[l].sum() - N * p) / math.sqrt(N * p * (1 - p))
        ok = (ntot > 0) & (pexp[l] > 0) & (pexp[l] < 1)
        jp = (counts[l][ok] - ntot[ok] * pexp[l][ok]) / np.sqrt(ntot[ok] * pexp[l][ok] * (1 - pexp[l][ok]))
        summary[l] = dict(p=p, pull=pull, jp=jp)
        if abs(pull) > args.nsigma:
            fails.append("%s: fraction %.5f vs weight %.5f, pull %.1f" % (l, counts[l].sum() / N, p, pull))
        if abs(jp.std() - 1) > 0.1:
            warns.append("%s: per-job pull RMS %.2f" % (l, jp.std()))
        print("%-26s %12d %10.5f %10.5f %7.2f %8.2f %8.2f" % (l, counts[l].sum(), counts[l].sum() / N, p, pull,
                                                                jp.mean(), jp.std()))
    ex = Counter(exhausted.values())
    print("\ninput that ran out and ended the job:")
    for l, n in ex.most_common():
        print("   %-26s %6d jobs" % (l, n))
    print("   %-26s %6d jobs" % ("(none)", len(jobs) - len(exhausted)))
    for l, n in ex.most_common()[1:]:
        if n > 0.01 * len(jobs):
            warns.append("%s ended %d jobs (the limiting input is %s)" % (l, n, ex.most_common(1)[0][0]))

    # ---------------- against the expected dts yields
    have, ratios, epulls = [], [], []
    if expected:
        have = [l for l in labels if l in expected]
        missing = [l for l in labels if l not in expected]
        if missing:
            warns.append("no expected yield for %s" % " ".join(missing))
        print("\n%-26s %12s %12s %8s %7s" % ("dataset", "sampled", "expected", "ratio", "pull"))
        for l in have:
            c, e = counts[l].sum(), expected[l]
            ratios.append(c / e)
            epulls.append((c - e) / math.sqrt(e))
            print("%-26s %12d %12.0f %8.4f %7.1f" % (l, c, e, ratios[-1], epulls[-1]))
            if abs(epulls[-1]) > args.nsigma:
                fails.append("%s: %d sampled vs %.0f expected, pull %.1f" % (l, c, e, epulls[-1]))
    else:
        print("\n(no expected yields given: pass --stage2-log or --expected to compare totals)")
    frac = None
    if target:
        frac = N / target
        tpull = (N - target) / math.sqrt(target)
        print("\ntotal sampled %d / target %.0f = %.4f of the requested livetime (pull %.1f)" % (N, target, frac, tpull))
        if abs(tpull) > args.nsigma:
            fails.append("total %d vs target %.0f (%.4f of the requested livetime)" % (N, target, frac))

    if args.check:
        print()
        for w in warns:
            print("WARN  %s" % w)
        for f in fails:
            print("FAIL  %s" % f)
        print("VALIDATION: %s" % ("FAIL" if fails else "PASS"))
    if not args.no_plots:
        make_plots(args, labels, counts, ntot, summary, ex, exhausted, jobs, fcl_w, fcl_src, expected, have,
                   ratios, epulls, target, frac, N)
    if args.check and fails:
        sys.exit(1)


def make_plots(args, labels, counts, ntot, summary, ex, exhausted, jobs, fcl_w, fcl_src, expected, have,
               ratios, epulls, target, frac, N):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from matplotlib.backends.backend_pdf import PdfPages
    except ImportError:
        sys.exit("matplotlib not found: use a python3 that has it (e.g. "
                 "/cvmfs/mu2e.opensciencegrid.org/env/ana/current/bin/python3) or pass --no-plots")
    plt.rcParams.update(RC)
    jobs_arr = np.array(jobs)

    # ---------------- plots
    pdf_path = args.out + ".pdf"
    with PdfPages(pdf_path) as pdf:
        # 1. aggregate fraction pulls
        fig, ax = plt.subplots(figsize=(9, 4))
        y = np.arange(len(labels))
        pulls = [summary[l]["pull"] for l in labels]
        ax.barh(y, pulls, height=0.55, color=[FLAG if abs(p) > args.nsigma else DATA for p in pulls])
        ax.axvline(0, color=REF, lw=1)
        for s in (-3, 3):
            ax.axvline(s, color=REF, lw=0.8, ls="--")
        ax.set_yticks(y, labels)
        ax.invert_yaxis()
        for yi, l in zip(y, labels):
            ax.text(ax.get_xlim()[1], yi, "  %.5f vs %.5f" % (counts[l].sum() / N, summary[l]["p"]),
                    va="center", fontsize=7, color=REF)
        ax.set_xlabel("(sampled - N·fraction) / binomial σ      [dashed: ±3σ]")
        ax.set_title("Sampled fraction over all %d jobs vs configured fraction (N = %d events)" % (len(jobs), N))
        fig.tight_layout()
        pdf.savefig(fig); plt.close(fig)

        # 2. per-job sampled fraction vs the .fcl weight
        fig, axes = grid(plt, len(labels))
        for ax, l in zip(axes, labels):
            f = counts[l][ntot > 0] / ntot[ntot > 0]
            w = fcl_w.get(l)
            ax.hist(f, bins=60, color=DATA)
            if w is not None:
                ax.axvline(w, color="#0b0b0b", lw=1.8, ls="--", zorder=3)
            ax.set_title(l)
            ax.text(0.02, 0.97, "weight %s\nmean   %.5f" % ("%.5f" % w if w is not None else "?", f.mean()),
                    transform=ax.transAxes, va="top", fontsize=7, family="monospace")
            ax.set_xlabel("sampled fraction per job")
            ax.set_ylabel("jobs")
        fig.suptitle("Per-job sampled fraction   [dashed: weight from %s]" % fcl_src, fontsize=11)
        fig.tight_layout()
        pdf.savefig(fig); plt.close(fig)

        # 3. per-job pulls
        fig, axes = grid(plt, len(labels))
        xs = np.linspace(-5, 5, 200)
        for ax, l in zip(axes, labels):
            jp = summary[l]["jp"]
            ax.hist(np.clip(jp, -6, 6), bins=np.linspace(-6, 6, 61), color=DATA, density=True)
            ax.plot(xs, np.exp(-xs ** 2 / 2) / math.sqrt(2 * math.pi), color=REF, lw=1.2, label="unit Gaussian")
            ax.set_title("%s   mean %.2f  RMS %.2f" % (l, jp.mean(), jp.std()))
            ax.set_xlabel("per-job pull (overflow in end bins)")
        fig.suptitle("Per-job pull: (count - n·fraction) / binomial σ   [line: unit Gaussian]", fontsize=11)
        fig.tight_layout()
        pdf.savefig(fig); plt.close(fig)

        # 4. events per job and the input that ended it
        fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 4), gridspec_kw={"width_ratios": [3, 2]})
        a1.hist(ntot, bins=80, color=DATA)
        a1.axvline(np.median(ntot), color=REF, ls="--", lw=1.2, label="median %d" % np.median(ntot))
        a1.set_xlabel("events per job")
        a1.set_ylabel("jobs")
        a1.set_title("Events per job (%d jobs)" % len(jobs))
        a1.legend()
        names = [l for l, _ in ex.most_common()] + ["(none)"]
        vals = [ex[l] for l in names[:-1]] + [len(jobs) - len(exhausted)]
        a2.barh(range(len(names)), vals, height=0.55, color=DATA)
        a2.set_yticks(range(len(names)), names)
        a2.invert_yaxis()
        for i, v in enumerate(vals):
            a2.text(v, i, " %d" % v, va="center", fontsize=8)
        a2.set_xlim(0, max(vals) * 1.15)
        a2.set_xlabel("jobs")
        a2.set_title("Input that ran out and ended the job")
        fig.tight_layout()
        pdf.savefig(fig); plt.close(fig)

        # 5. events per job vs job index
        fig, ax = plt.subplots(figsize=(11, 4))
        med = np.median(ntot)
        low = ntot < 0.5 * med
        ax.plot(jobs_arr[~low], ntot[~low], ".", ms=2, color=DATA, label="job")
        if low.any():
            ax.plot(jobs_arr[low], ntot[low], ".", ms=5, color=FLAG, label="< half the median (%d jobs)" % low.sum())
        ax.axhline(med, color=REF, ls="--", lw=1, label="median")
        ax.set_xlabel("job index (subrun)")
        ax.set_ylabel("events")
        ax.set_title("Events per job vs job index")
        ax.legend(loc="lower right")
        fig.tight_layout()
        pdf.savefig(fig); plt.close(fig)

        # 6. against the expected dts yields
        if have:
            fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 4.5), sharey=True)
            y = np.arange(len(have))
            a1.errorbar(ratios, y, xerr=[1 / math.sqrt(expected[l]) for l in have], fmt="o", ms=5,
                        color=DATA, ecolor=DATA, elinewidth=1.5, capsize=3)
            a1.axvline(1, color=REF, lw=1)
            a1.set_yticks(y, have)
            a1.invert_yaxis()
            a1.set_xlabel("sampled / expected dts yield")
            a1.set_title("Sampled vs expected (dts eff. included)")
            a2.barh(y, epulls, height=0.55, color=[FLAG if abs(p) > args.nsigma else DATA for p in epulls])
            a2.axvline(0, color=REF, lw=1)
            a2.set_xlabel("(sampled - expected) / √expected")
            a2.set_title("Poisson pull")
            if target:
                fig.suptitle("Total sampled %d / target %.0f = %.4f of the requested livetime" % (N, target, frac),
                             fontsize=11, color=FLAG if abs(frac - 1) > args.nsigma / math.sqrt(target) else "#0b0b0b")
            fig.tight_layout()
            pdf.savefig(fig); plt.close(fig)
    print("\nwrote %s" % pdf_path)


if __name__ == "__main__":
    main()

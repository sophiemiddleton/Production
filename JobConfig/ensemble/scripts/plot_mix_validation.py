#!/usr/bin/env python3
"""Validation plots for a signal-mixed MDS (mds.sh signal + mix) against the unmixed MDS it was drawn from.

The mixed sample is N known-physics ntuple files of the MDS plus a signal ntuple. Expected after cuts:
  known physics = reference MDS post-cut x (known events in the mix / events the reference processed)
  signal        = the signal-only ntuple post-cut (the same events, processed alone)

Inputs are the pyfitter selection outputs, process.py --nofit --loc local, all with the same --version:
<dir>/parquet/<name>_postcut.parquet and <dir>/cutflows/<name>.csv. This script itself needs only
numpy, pandas, scipy and matplotlib (e.g. the Mu2e ana environment's python3).

Run the selection on the mix's input files (pe_<N>/mixed_files.txt) rather than the merged files: with
a signal ntuple from a different EventNtuple version, uproot cannot read trkmcsim in the merged files.
Process the signal ntuple on its own, since in one job uproot reuses the first file's SimInfo layout,
and add the two results for --mix.

e.g.
  plot_mix_validation.py --mix-dir MDS4b_CeM1e-13_mix --mix MDS4b_CeM1e-13_mixsum \\
    --sig MDS4b_CeM1e-13_sigonly --ref-dir MDS4b_run1a --ref MDS4b --out MDS4b_CeM1e-13_mix/validation
"""

import argparse
import os

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from scipy import stats

DATA = "#2a78d6"   # mixed sample
REF = "#52514e"    # known physics expectation
SIG = "#eb6834"    # injected signal
FLAG = "#e34948"
GRID = "#e4e3df"

plt.rcParams.update({
    "axes.edgecolor": REF, "axes.labelcolor": "#0b0b0b", "axes.titlesize": 10, "axes.labelsize": 9,
    "xtick.color": REF, "ytick.color": REF, "xtick.labelsize": 8, "ytick.labelsize": 8,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6, "axes.axisbelow": True,
    "axes.spines.top": False, "axes.spines.right": False, "legend.frameon": False, "legend.fontsize": 8,
})


def load(d, name):
    post = pd.read_parquet(os.path.join(d, "parquet", f"{name}_postcut.parquet"))
    flow = pd.read_csv(os.path.join(d, "cutflows", f"{name}.csv"))
    return post, flow


def poisson_p(n, mu):
    """Two-sided Poisson p-value of observing n given mu."""
    lo = stats.poisson.cdf(n, mu)
    hi = stats.poisson.sf(n - 1, mu)
    return min(1.0, 2 * min(lo, hi))


def chi2_hist(obs, exp, var_exp):
    m = (exp > 0) | (obs > 0)
    var = np.where(exp > 0, exp, 1) + var_exp
    chi2 = float(np.sum((obs[m] - exp[m]) ** 2 / var[m]))
    ndf = int(m.sum())
    return chi2, ndf, float(stats.chi2.sf(chi2, ndf))


def spectrum_page(pdf, png, var, bins, xlabel, mix, ref, sig, scale, title):
    o, _ = np.histogram(mix[var], bins)
    r, _ = np.histogram(ref[var], bins)
    s, _ = np.histogram(sig[var], bins)
    known = r * scale
    exp = known + s
    chi2, ndf, p = chi2_hist(o, exp, r * scale ** 2)

    fig, (ax, axr) = plt.subplots(2, 1, figsize=(7, 5.6), sharex=True, gridspec_kw={"height_ratios": [3, 1], "hspace": 0.06})
    ax.stairs(known, bins, fill=True, color=REF, alpha=0.35, label=f"known physics, MDS4b x {scale:.4f}  ({known.sum():.1f})")
    ax.stairs(exp, bins, baseline=known, fill=True, color=SIG, alpha=0.75, label=f"injected signal, processed alone  ({s.sum()})")
    ax.stairs(exp, bins, color="#0b0b0b", linewidth=1)
    c = 0.5 * (bins[1:] + bins[:-1])
    ax.errorbar(c, o, yerr=np.sqrt(o), fmt="o", ms=4, color=DATA, label=f"mixed sample  ({o.sum()})")
    ax.set_ylabel("events / bin")
    ax.set_title(f"{title}   chi2/ndf = {chi2:.1f}/{ndf}, p = {p:.2f}")
    ax.legend(loc="upper right")
    pull = np.where(exp > 0, (o - exp) / np.sqrt(np.where(exp > 0, exp, 1) + r * scale ** 2), 0)
    axr.bar(c, pull, width=np.diff(bins), color=np.where(np.abs(pull) > 3, FLAG, DATA), edgecolor="white", linewidth=1)
    axr.axhline(0, color=REF, lw=0.8)
    axr.set_ylim(-4, 4)
    axr.set_ylabel("pull")
    axr.set_xlabel(xlabel)
    pdf.savefig(fig)
    fig.savefig(png, dpi=130, bbox_inches="tight")
    plt.close(fig)
    return chi2, ndf, p


def cutflow_page(pdf, png, mixf, reff, sigf, scale):
    # Cumulative counts compare only while both cut lists run in the same order (an older cut version
    # can order them differently or lack some, e.g. no_tsda), then the final cut
    mn, rn = list(mixf["name"]), list(reff["name"])
    k = 0
    while k < min(len(mn), len(rn)) and mn[k] == rn[k]:
        k += 1
    names = mn[:k] + ([mn[-1]] if k < len(mn) and mn[-1] in rn else [])
    o = mixf.set_index("name").loc[names, "events_passing"].to_numpy(float)
    r = reff.set_index("name").reindex(names)["events_passing"].to_numpy(float)
    s = sigf.set_index("name").reindex(names)["events_passing"].fillna(0).to_numpy(float)
    exp = r * scale + s
    ratio = o / exp
    err = np.sqrt(1 / np.maximum(o, 1) + 1 / np.maximum(r, 1))
    z = (o - exp) / np.sqrt(exp + r * scale ** 2)

    fig, (ax, axr) = plt.subplots(2, 1, figsize=(8, 6.5), sharex=True, gridspec_kw={"height_ratios": [2, 1], "hspace": 0.06})
    x = np.arange(len(names))
    ax.plot(x, exp, color=REF, lw=2, label="expected: MDS4b x scale + signal alone")
    ax.plot(x, s, color=SIG, lw=2, label="signal alone")
    ax.plot(x, o, "o", ms=5, color=DATA, label="mixed sample")
    ax.set_yscale("log")
    ax.set_ylabel("events passing")
    ax.set_title("Cut flow: mixed sample vs expectation")
    ax.legend(loc="lower left")
    bad = np.abs(z) > 3
    axr.errorbar(x[~bad], ratio[~bad], yerr=err[~bad] * ratio[~bad], fmt="o", ms=4, color=DATA)
    axr.errorbar(x[bad], ratio[bad], yerr=err[bad] * ratio[bad], fmt="o", ms=4, color=FLAG)
    axr.axhline(1, color=REF, lw=0.8)
    axr.set_ylabel("mixed / expected")
    axr.set_xticks(x)
    axr.set_xticklabels(names, rotation=60, ha="right", fontsize=7)
    fig.subplots_adjust(bottom=0.25)
    pdf.savefig(fig)
    fig.savefig(png, dpi=130, bbox_inches="tight")
    plt.close(fig)
    return pd.DataFrame({"cut": names, "mixed": o.astype(int), "expected": exp, "signal": s.astype(int), "z": z})


def signal_page(pdf, png, mix, sig):
    key = ["momentum", "time"]
    found = mix.merge(sig[key].drop_duplicates(), on=key, how="inner")
    fig, axes = plt.subplots(1, 2, figsize=(9, 3.6))
    b = np.linspace(100, 110, 41)
    axes[0].hist(sig["momentum"], b, histtype="step", color=SIG, lw=2, label=f"signal processed alone ({len(sig)})")
    axes[0].hist(found["momentum"], b, histtype="step", color=DATA, lw=1.2, ls="--", label=f"found in mixed sample ({len(found)})")
    axes[0].set_xlabel("reco momentum [MeV/c]")
    axes[0].set_ylabel("events / 0.25 MeV/c")
    axes[0].legend(loc="upper left")
    axes[0].set_title("Injected signal after cuts")
    d = sig["momentum"] - sig["mom_true"]
    axes[1].hist(d, np.linspace(-3, 1.5, 46), color=SIG, alpha=0.8, edgecolor="white")
    axes[1].set_xlabel("reco - true momentum [MeV/c]")
    axes[1].set_title(f"Signal resolution (median {np.median(d):+.2f} MeV/c)")
    fig.tight_layout()
    pdf.savefig(fig)
    fig.savefig(png, dpi=130, bbox_inches="tight")
    plt.close(fig)
    return len(found)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mix-dir", default=".")
    ap.add_argument("--mix", required=True)
    ap.add_argument("--sig", required=True)
    ap.add_argument("--ref-dir", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--out", default="validation")
    a = ap.parse_args()

    mix, mixf = load(a.mix_dir, a.mix)
    sig, sigf = load(a.mix_dir, a.sig)
    ref, reff = load(a.ref_dir, a.ref)
    n_mix = int(mixf.loc[mixf.name == "No cuts", "events_passing"].iloc[0])
    n_sig = int(sigf.loc[sigf.name == "No cuts", "events_passing"].iloc[0])
    n_ref = int(reff.loc[reff.name == "No cuts", "events_passing"].iloc[0])
    scale = (n_mix - n_sig) / n_ref

    os.makedirs(a.out, exist_ok=True)
    p = lambda n: os.path.join(a.out, n)
    with PdfPages(p("mix_validation.pdf")) as pdf:
        mom = spectrum_page(pdf, p("mix_mom.png"), "momentum", np.linspace(100, 110, 21), "reco momentum [MeV/c]",
                            mix, ref, sig, scale, "Momentum after cuts")
        t0 = spectrum_page(pdf, p("mix_t0.png"), "time", np.linspace(475, 1650, 25), "t0 [ns]",
                           mix, ref, sig, scale, "t0 after cuts")
        flow = cutflow_page(pdf, p("mix_cutflow.png"), mixf, reff, sigf, scale)
        nfound = signal_page(pdf, p("mix_signal.png"), mix, sig)

    known_exp = len(ref) * scale
    exp = known_exp + len(sig)
    lines = [
        f"Mixed sample {a.mix} vs reference {a.ref}",
        f"  events processed: mixed {n_mix}, signal alone {n_sig}, reference {n_ref}",
        f"  known-physics scale (mixed - signal) / reference = {scale:.5f}",
        "",
        "After cuts (100-110 MeV/c, 475-1650 ns)",
        f"  known physics expected   {known_exp:8.1f}   (reference {len(ref)} x scale)",
        f"  signal (processed alone) {len(sig):8d}",
        f"  expected total           {exp:8.1f}",
        f"  mixed sample             {len(mix):8d}   z = {(len(mix) - exp) / np.sqrt(exp + len(ref) * scale**2):+.2f}, Poisson p = {poisson_p(len(mix), exp):.3f}",
        f"  signal events found in the mixed sample: {nfound} of {len(sig)}",
        f"  momentum chi2/ndf = {mom[0]:.1f}/{mom[1]}, p = {mom[2]:.3f}",
        f"  t0       chi2/ndf = {t0[0]:.1f}/{t0[1]}, p = {t0[2]:.3f}",
        "",
        "Cut flow (z = (mixed - expected) / sigma, sigma includes the reference statistics)",
        flow.to_string(index=False, float_format=lambda v: f"{v:.1f}"),
    ]
    txt = "\n".join(lines)
    print(txt)
    with open(p("mix_report.txt"), "w") as f:
        f.write(txt + "\n")


if __name__ == "__main__":
    main()

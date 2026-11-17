#! /usr/bin/env python
"""
Muon stops and captures per proton on target (POT) in the Al stopping target.

This module is the single place where Production turns the stage efficiencies
in the SimEfficiencies2 DB table into

    stops/POT    = MuBeamCat.eff * MuminusStopsCat.eff * MuminusTargetStopPrescale
    captures/POT = stops/POT * f_cap

It is used by the ensemble normalizations (JobConfig/ensemble/python) and by
the muon-capture normalization studies (STM, CAPHRI), which need the true
number of stops and captures in a simulated sample:

    N_stop = sum over events of PBI (true POT per microbunch) * stops/POT
    N_cap  = N_stop * f_cap

Why the prescale appears
------------------------
The TargetStops sample is made by MuBeamResampler.fcl with a
RandomPrescaleFilter (TargetStopPrescaleFilter) whose nPrescale is
Pileup.MuminusTargetStopPrescale in JobConfig/pileup/prolog.fcl. The stored
MuminusStopsCat efficiency therefore counts only 1 in that many stops. The
mixing multiplies the same factor back in (meanEventsPerPOTFactors in
JobConfig/mixing/epilog.fcl). This module reads the value from the fcl so
the two cannot drift apart.

Capture fraction
----------------
CAPTURES_PER_STOPPED_MUON (0.609) is the value used for physics yields.
The Offline Pileup generator, which makes the MuStopPileup sample used in
mixing, chooses decay or capture with physicsParams.Al.decayFraction from
Offline/GlobalConstantsService/data/globalConstants_01.txt (0.39 at the time
of writing, i.e. 0.61 captures per stop). For a closure test on a mixed
sample, pass the fraction the sample was generated with as capture_fraction.
"""

import os
import re

# --- Muon fates in Al --------------------------------------------------------
# Fraction of stopped muons that undergo nuclear capture
CAPTURES_PER_STOPPED_MUON = 0.609
# Fraction of stopped muons that decay in orbit (DIO): 1 - CAPTURES_PER_STOPPED_MUON
DIO_PER_STOPPED_MUON = 0.391

# --- SimEfficiencies2 --------------------------------------------------------
# Stages whose efficiencies multiply to give (prescaled) target stops per POT
MUON_STOP_STAGES = ("MuBeamCat", "MuminusStopsCat")

# Default DB selection, as used by the ensemble normalizations
DEFAULT_PURPOSE = "Sim_best"
DEFAULT_VERSION = "v1_1"
DEFAULT_RUN = 1430

# --- Prescale ----------------------------------------------------------------
_PILEUP_PROLOG = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "pileup", "prolog.fcl"
)
_PRESCALE_RE = re.compile(r"^\s*MuminusTargetStopPrescale\s*:\s*([0-9.eE+-]+)", re.MULTILINE)


def muminus_target_stop_prescale(prolog=_PILEUP_PROLOG):
    """Return Pileup.MuminusTargetStopPrescale as set in JobConfig/pileup/prolog.fcl."""
    with open(prolog) as f:
        text = f.read()
    matches = _PRESCALE_RE.findall(text)
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected one MuminusTargetStopPrescale in {prolog}, found {len(matches)}"
        )
    return float(matches[0])


def fetch_sim_efficiencies(purpose=DEFAULT_PURPOSE, version=DEFAULT_VERSION, run=DEFAULT_RUN):
    """Return the SimEfficiencies2 table content (CSV text) for one DB selection."""
    import DbService  # only needed when reading the DB

    db_tool = DbService.DbTool()
    db_tool.init()
    db_tool.setArgs([
        "print-run",
        "--purpose", purpose,
        "--version", version,
        "--run", str(run),
        "--table", "SimEfficiencies2",
        "--content",
    ])
    db_tool.run()
    return db_tool.getResult()


def parse_sim_efficiencies(text):
    """
    Parse SimEfficiencies2 CSV content into
    {tag: {"numerator": int, "denominator": int, "eff": float}}.
    Lines that are not table rows (comments, headers, blanks) are skipped.
    """
    table = {}
    for line in text.splitlines():
        words = [w.strip() for w in line.split(",")]
        if len(words) < 4:
            continue
        try:
            row = {
                "numerator": int(words[1]),
                "denominator": int(words[2]),
                "eff": float(words[3]),
            }
        except ValueError:
            continue
        table[words[0]] = row
    return table


def stops_per_pot(table, prescale=None):
    """
    Target-stopped muons per POT from a parsed SimEfficiencies2 table.
    prescale defaults to MuminusTargetStopPrescale read from the pileup prolog.
    """
    missing = [tag for tag in MUON_STOP_STAGES if tag not in table]
    if missing:
        raise KeyError(f"SimEfficiencies2 is missing {missing}")
    if prescale is None:
        prescale = muminus_target_stop_prescale()
    rate = prescale
    for tag in MUON_STOP_STAGES:
        rate *= table[tag]["eff"]
    return rate


def captures_per_pot(table, prescale=None, capture_fraction=CAPTURES_PER_STOPPED_MUON):
    """Muon captures per POT: stops_per_pot * capture_fraction."""
    return stops_per_pot(table, prescale) * capture_fraction


def load_stops_per_pot(purpose=DEFAULT_PURPOSE, version=DEFAULT_VERSION, run=DEFAULT_RUN,
                       prescale=None):
    """Read SimEfficiencies2 from the DB and return stops/POT."""
    return stops_per_pot(parse_sim_efficiencies(fetch_sim_efficiencies(purpose, version, run)),
                         prescale)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Print muon stops and captures per POT")
    parser.add_argument("--purpose", default=DEFAULT_PURPOSE)
    parser.add_argument("--version", default=DEFAULT_VERSION)
    parser.add_argument("--run", type=int, default=DEFAULT_RUN)
    parser.add_argument("--capture-fraction", type=float, default=CAPTURES_PER_STOPPED_MUON)
    args = parser.parse_args()

    table = parse_sim_efficiencies(fetch_sim_efficiencies(args.purpose, args.version, args.run))
    prescale = muminus_target_stop_prescale()
    for tag in MUON_STOP_STAGES:
        print(f"{tag:16s} eff = {table[tag]['eff']:.6e}")
    print(f"{'prescale':16s}       {prescale:g}")
    print(f"stops/POT        = {stops_per_pot(table, prescale):.6e}")
    print(f"captures/POT     = {captures_per_pot(table, prescale, args.capture_fraction):.6e}"
          f"  (f_cap = {args.capture_fraction})")

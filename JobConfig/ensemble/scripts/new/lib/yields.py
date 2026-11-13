#!/usr/bin/env python3
"""
Compute ensemble yields in one pass and print them as KEY="VALUE" lines that
mds.sh merges into the tag's manifest.

  yields.py background --livetime 5.72e6 --BB 1BB --dioemin 95 --ipaemin 70 \
                       --rpcemin 50 --tmin 350 [--rmcn0emin 80] [--rmcn1emin 80]
  yields.py signal --livetime <on-spill s> --BB 1BB --rue 1e-13 [--seed N]

The functions and argument conventions are the same as calculateEvents.py, so
the numbers match what Stage1_initiate_ensemble.sh produced. Any failure exits
non-zero instead of leaving an empty yield behind.
"""
import argparse
import contextlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "python"))
import normalizations as nm  # noqa: E402


def emit(values):
    for k, v in values:
        print('%s="%s"' % (k, v))


def background(args):
    lt = float(args.livetime)
    bb = str(args.BB)
    out = []
    # keep library chatter off stdout, which the caller parses
    with contextlib.redirect_stdout(sys.stderr):
        nm.set_verbose(False)
        duty = nm.get_duty_factor(bb)
        npot = nm.get_pot(lt, bb, False)
        out += [
            ("beam_onspill_time", lt),
            ("beam_livetime", lt / duty),
            ("beam_npot", "%.2e" % npot),
            ("beam_nmot", "%.2e" % (npot * nm.target_stopped_muons_per_pot)),
            ("beam_pot", "%.2e" % npot),
            ("duty_factor", duty),
            ("dio_events", nm.dio_normalization(lt, float(args.dioemin), bb)),
            ("ipa_events", nm.ipaMichel_normalization(lt, float(args.ipaemin), bb)),
            ("rpc_internal_events", nm.rpc_normalization(lt, float(args.tmin), "1", str(args.rpcemin), bb)),
            ("rpc_external_events", nm.rpc_normalization(lt, float(args.tmin), "0", str(args.rpcemin), bb)),
        ]
        if args.rmcn0emin:
            e = float(args.rmcn0emin)
            out += [
                ("rmc_n0_internal_events", nm.rmc_0n_normalization(lt, e, internal=1, run_mode=bb)),
                ("rmc_n0_external_events", nm.rmc_0n_normalization(lt, e, internal=0, run_mode=bb)),
            ]
        if args.rmcn1emin:
            e = float(args.rmcn1emin)
            out += [
                ("rmc_n1_internal_events", nm.rmc_1n_normalization(lt, e, internal=1, run_mode=bb)),
                ("rmc_n1_external_events", nm.rmc_1n_normalization(lt, e, internal=0, run_mode=bb)),
            ]
    emit(out)


def signal(args):
    with contextlib.redirect_stdout(sys.stderr):
        nm.set_verbose(False)
        if args.seed is not None:
            nm.np.random.seed(int(args.seed))
        n = nm.ce_normalization(float(args.livetime), float(args.rue), str(args.BB))
    emit([("nsig", int(n))])


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="mode", required=True)
    b = sub.add_parser("background")
    b.add_argument("--livetime", required=True, help="on-spill time [s]")
    b.add_argument("--BB", required=True)
    b.add_argument("--dioemin", required=True)
    b.add_argument("--ipaemin", required=True)
    b.add_argument("--rpcemin", required=True)
    b.add_argument("--tmin", required=True)
    b.add_argument("--rmcn0emin", default="")
    b.add_argument("--rmcn1emin", default="")
    s = sub.add_parser("signal")
    s.add_argument("--livetime", required=True, help="on-spill time [s]")
    s.add_argument("--BB", required=True)
    s.add_argument("--rue", required=True)
    s.add_argument("--seed", default=None)
    a = p.parse_args()
    background(a) if a.mode == "background" else signal(a)

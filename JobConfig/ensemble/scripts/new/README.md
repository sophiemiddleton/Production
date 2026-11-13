# mds.sh: MDS workflow driver

A single entry point for building a Mock Data Sample. It replaces the
`Stage0`–`Stage6` scripts, which have been removed from the repository; they
are in the history before commit `ef6db55d`, e.g.
`git show ef6db55d^:JobConfig/ensemble/scripts/Stage5_signal.sh`.

Outside this directory the workflow uses:
- `../../python/make_template_fcl.py` (`build`) and `../../python/normalizations.py`
  (imported by `lib/yields.py`)
- `../plot_ensemble_validation.py` and `../ensemble_livetime.py` (`validate`)
- `../../fcl/split.fcl` and `EventNtuple/fcl/from_mcs-mockdata.fcl` (`signal`)

```
mds.sh init      --tag MDS4a --version ax --livetime 5.72e6     # Stage 1
mds.sh build     --tag MDS4a                                    # Stage 2
mds.sh publish   --tag MDS4a --dry-run                          # Stage 3: check first
mds.sh publish   --tag MDS4a
    ── POMS: ensemble campaign (mkidxdef + launch, as mu2epro) ──
mds.sh validate  --tag MDS4a                                    # Stage 4 (reads the log dataset on pnfs)
mds.sh digireco  --tag MDS4a                                    # Stage 3 --append
    ── POMS: json2jobdef for digi / reco / ntuple, relaunch ──
mds.sh signal    --tag MDS4a --signal <name> --rate 1e-13 --nexp 3 --seed 1   # finds a compatible signal mcs
mds.sh mix       --tag MDS4a                                    # Stage 6
mds.sh status    --tag MDS4a                                    # at any point
```

`mds.sh <step> --help` lists every option of a step. Each step except `mix`
prints the next command when it finishes.

Set up your environment first (muse setup and mu2einit, so that `samweb`, `mu2e`,
`mu2ejobdef` and so on are in PATH). Each step checks for the tools it needs.
Three things run locally in that environment rather than in a version taken
from the manifest:
- `signal` runs the splitter and the signal ntuple job with your `mu2e`. Set up
  the same EventNtuple as the MDS ntuples (the manifest's `anaversion`, i.e.
  `Musings/Analysis<release>/<anaversion>`); see [Known limitations](#known-limitations).
- `mix` runs your `hadd`.
- `init --compute-livetime` runs your `mu2e` with `printCosmicLivetime.fcl`.

`validate` needs matplotlib for its plots. It uses `$MDS_PYTHON`, by default the
Mu2e ana environment's `python3` when it is on cvmfs, otherwise `python3`.

## How it is organised

**One directory per tag.** Everything for `MDS4a` lives in `<workroot>/MDS4a/`.
The workroot is `--workroot DIR` if given, otherwise `$MDS_WORKROOT`, otherwise
the current directory. Nothing is created or deleted outside that directory,
apart from SAM, tape and `poms_map`: the index definition in `build`, the
declares, uploads and `poms_map` copy in `publish`, and the `poms_map` copy in
`digireco --install`.

**One manifest per tag.** `MDS4a/manifest.env` is a sourceable `key="value"`
file. `init` writes the configuration with the same keys as Stage 1's
`<TAG>.txt`, together with the release and version, DB purpose and version,
the SimJob setup and Analysis version, the names of every dataset the campaign
will produce, POT, the duty factor and the expected yields. Later steps add:
- `build`: the input dataset it picked for each process (`input_ds_<label>`),
  the expected dts yields (`dts_expected_<label>`, `sample_target`), the
  tarball, its job count (`jobdef_njobs`) and the index definition
- `publish`: the tag-info file and the campaign JSON's path in `poms_map`
- `validate`: `validate_logs` and the livetime actually built
  (`true_onspilltime`, `true_beam_livetime`, `true_beam_npot`, ...)
- `digireco`: `stages_json` and `digi_merge`

All steps read their settings from the manifest. The version letters (`ax`) are
given once, to `init`.

**Step state.** `init`, `build`, `publish`, `validate` and `digireco` record
`step_<name>_done` in the manifest, and each refuses to run before the step it
depends on (`build` after `init`, and so on; `signal` after `digireco`).
`build` and `publish` skip themselves when already done; `validate` and
`digireco` can be rerun. `init` refuses to overwrite an existing manifest.
`build` refuses after `publish`, because the tarball on tape would no longer
match. `--force` overrides all of these.

`signal` and `mix` keep their state in the signal set instead: `signal` refuses
an existing `signal/<label>/` and `mix` skips a pseudo-experiment that already
has a `merged_list.txt`, unless `--force`. Several signal sets can live side by
side under different `--label`s.

A lock (`.lock`) stops two steps from running on the same tag at once. All
output is also written to `MDS4a/run_logs/<step>-<time>.log`.

**Outward-facing actions are safe to rerun.** `publish` checks SAM before each
declare, upload and add-location, and only copies into `poms_map` when the file
there is missing or identical. Use `--force` to replace a different file. If the
step fails partway through, run it again. `--dry-run` prints every action
without doing it. The same applies to the index definition in `build` and the
copy in `digireco --install`.

## Workdir layout

```
MDS4a/
  manifest.env                  config, yields, dataset names, step state
  run_logs/                     output of every mds.sh run
  lists/                        full and chosen file lists per input dataset
  filenames_<label>             paths read by make_template_fcl.py
  filenames_<label>_<N>.txt     the same files as SAM names, for mu2ejobdef
  SamplingInput_sr*.fcl         template FCL
  cnf.*.ensemble.*.tar          job tarball            (+ .json, its SAM metadata)
  cnf.*.<TAG>-info.*.txt        tag-info file: the manifest without step_* lines (+ .json)
  MDC2025-MDS4a.json            ensemble campaign  (copied to poms_map)
  MDC2025-MDS4a-stages.json     digi / reco / ntuple stages
  make_template.out             make_template_fcl.py output (expected dts yields)
  validate.txt  validate.csv  validate.pdf    validate report, per-job table, plots
  livetime.txt                  livetime actually built (ensemble_livetime.py)
  signal/<label>/               one signal set (default label <--signal>_<--rate>)
    signal.env                  signal dataset, livetime, recoeff, seed, nsig_<i>
    signal_all.txt  known_all.txt
    pe_<i>/
      signal_files.txt  splitter.fcl  ntuple.fcl  splitter.log  ntuple.log
      mcs.<owner>.<signal>Split.<dsconf>.<i>.art     the split signal events
      nts.<owner>.<signal>Split.<dsconf>.<i>.root    their ntuple
      mixed_files.txt           signal ntuple + known-physics ntuples, shuffled
      merged/                   nts.mu2e.ensemble<TAG>Mix<BB>_<signal>_<rate>_<livetime>.<i>_<n>.root, hadd_<n>.log
      merged_list.txt           the merged files
```

## Choosing the signal sample

Without `--signalmcs`, `signal` searches SAM for
`mcs.mu2e.<signal><mode>[Triggered].<release><letters>_<db>.art` with the same
release and digi mode (`OnSpill` or `Mix<N>BB`) as the MDS. `--signal` may name
the mode itself, and a name ending in `Triggered` prefers triggered samples.
Candidates are ranked by: same DB purpose/version as the MDS, the Triggered
preference, same SimJob version, then the latest version; the first with files
is used. It warns when the release, DB version or digi mode differs from the
MDS's, and when the sample is not trigger-filtered.

The number of signal events per pseudo-experiment is a Poisson draw for the
on-spill livetime used (`lib/yields.py signal`), times `--recoeff`.

## Checking a mixed sample

`../plot_mix_validation.py` compares a signal set with the MDS it was drawn
from: known physics expected = the MDS after cuts × (known events in the mix /
MDS events), plus the signal ntuple after cuts. It plots momentum and t0 after
cuts, the cut flow and the injected signal, and writes a report. It needs only
numpy, pandas, scipy and matplotlib, but its inputs are pyfitter's
`process.py --nofit --loc local` outputs (`parquet/<name>_postcut.parquet`,
`cutflows/<name>.csv`), all made with the same `--version`. Run the selection on
`pe_<i>/mixed_files.txt` rather than the merged files, with the signal ntuple on
its own; the script's docstring explains why and shows an example.

## Known limitations

- **EventNtuple version of the signal ntuple.** `signal` makes the signal
  ntuple with whatever EventNtuple is set up (see above), not the manifest's
  `anaversion`. If it differs from the MDS ntuples', `hadd` in `mix` takes the
  first file's tree layout: branches only the signal has are dropped, and
  classes that changed without a version bump (e.g. `SimInfo`, `MCStepInfo`
  between EventNtuple v6.15 and v6.16) leave `trkmcsim` and `trkmcvd`
  unreadable by uproot in every merged file. MDS4b + CeMLeadingLog 1e-13
  (signal made with v6.16.0, MDS with v6.15.2) has this problem.
- **Signal events are not blinded.** The signal ntuple keeps its own run,
  subrun and event numbers (for MDS4b, all signal events are in subrun 416,
  which no known-physics event uses), and its own DB version.
- **Livetime when `validate` has not run in this workroot.** `signal` takes the
  dts livetime from `true_beam_livetime`, which only `validate` writes. Without
  it, it warns and uses the requested `beam_livetime`, which overstates the
  livetime by the built/target fraction (2.6% for MDS4b), so the signal yield
  is too high by the same amount.

## Differences from the Stage scripts

Fixes:
- Each input is looked up in SAM on its own. In Stage 2, RMC 1N reused the 0N
  version, and RPC External reused the RPC Internal version.
  `--pin LABEL=letters` overrides a lookup.
- When looking for the latest version, letters are sorted by length and then
  alphabetically, so `aa` counts as later than `z`.
- A failed version lookup, a missing expected yield or an empty file list now
  stops the step instead of continuing.
- The paths given to `make_template_fcl.py` and the SAM names given to
  `mu2ejobdef` come from the same sorted list, so both see the same files in
  the same order. File availability is counted at the same location the list
  uses (`--tape` for RPC Internal and IPA, as before).
- `build` stops when a dataset has fewer files than jobs or fewer generated
  events than its expected yield, and warns when the N files actually chosen
  hold fewer generated events than the expected yield.
- `publish` declares and uploads only its own two files. It no longer runs
  `ls *.json` / `ls *.tar`. The tag-info file is a copy of the manifest without
  the `step_*` lines, so the manifest stays in place for later steps.
- `validate` runs `../plot_ensemble_validation.py --check` on the logs where
  they are on pnfs. It compares each process's sampled fraction with its FCL
  weight, and each total with the expected **dts** yield (generated-level
  yield × dts efficiency, which `build` records as `dts_expected_<label>` and
  `sample_target`). Stage 4 only summed the counts. It also reports which input
  ran out and ended each job, and writes plots to `validate.pdf`. It never
  deletes files. A failed check stops the step unless `--accept`. The same
  script works on its own for tags made with the Stage scripts.
- `validate` then records the livetime that was actually built,
  `true_onspilltime` = requested × (events built / sampled target), with
  `true_beam_livetime` and `true_beam_npot`, in the manifest and `livetime.txt`.
  Events built come from SAM when `samweb` is set up, otherwise from the logs.
  `../ensemble_livetime.py` also gives a per-process estimate (N_i / E_i) as a
  cross-check, and works on its own with `--logs` or `--from-csv`, plus
  `--livetime` and `--stage2-log` (or `--manifest`).
- `signal` runs `mu2e` directly and checks its exit status and output file. The
  old `cmd=$(mu2e ...); $cmd` ran the job's output as a shell command. Splitter
  and ntuple file names now use the same owner. The FHiCL file list has no
  trailing comma. The duty factor comes from `normalizations.py`, so 2BB uses
  0.246 rather than 0.323. The known-physics livetime per ntuple file comes from the dts
  file count and `digi_merge` (with `--dts-nfiles` to override the count), and
  only the ntuple files that actually exist are used. Files lost in
  digi/reco/ntuple therefore reduce the livetime rather than stopping the step.
  Stage 5 hardcoded 496 files. The dts livetime is `true_beam_livetime` from
  `validate` when it's there. Signal generated events come from SAM, with a
  `--signal-ngen` override, instead of being hardcoded as 1e7. A pseudo-experiment with zero
  signal events skips the splitter.
- `signal` finds a compatible signal dataset itself (see
  [Choosing the signal sample](#choosing-the-signal-sample)); Stage 5 took the
  dataset name as given.
- `--seed` makes the signal yield and every file shuffle reproducible
  (pseudo-experiment i uses seed + i).
- `init` always uses `--livetime` when you give it, or `--compute-livetime` to
  run printCosmicLivetime. `beam_pot` is now filled in.

Things that behave differently on purpose:
- `digireco` writes `<release>-<TAG>-stages.json` and does **not** overwrite the
  campaign JSON in `poms_map`, which `Stage3 --append` did. It prints a
  `json2jobdef` command for each of the three stages; Stage 3 printed only the
  digi one. `--install` copies the stages JSON into `poms_map` under its own
  name, and `--jobdefs` chooses the jobdefs file.
- The value in the digi stage's `input_data` is `--digi-merge`, default 100.
  `Stage3 --append` never read the config, so 100 is what it always used.
- The signal yield is still a Poisson draw scaled by `--recoeff`, as in Stage 5.
- `mix` does no blinding (Stage 6 was `Stage6_blind_and_mix.sh`); it shuffles
  and hadds, `--files-per-merge` files at a time (default 2).

## Testing

No mocks are included. To exercise the logic without SAM or the grid, put stub
`samweb`, `mu2e`, `mu2ejobdef`, ... scripts first in `PATH`, and point the
outputs elsewhere with the environment overrides `MDS_WORKROOT`, `POMS_MAP`,
`MDS_LOG_ROOT`, `ENSEMBLE_PY` and `MDS_PYTHON`.

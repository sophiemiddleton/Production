# mds.sh: MDS workflow driver

A single entry point for building a Mock Data Sample. It replaces running
`Stage0`–`Stage6` by hand. The original scripts in `../` are unchanged. This
workflow only calls `../../python/make_template_fcl.py` and imports
`../../python/normalizations.py`.

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

`mds.sh <step> --help` lists every option of a step. Each step prints the next
command when it finishes.

Set up your environment first (muse setup and mu2einit, so that `samweb`, `mu2e`,
`mu2ejobdef` and so on are in PATH). Each step checks for the tools it needs.

## How it is organised

**One directory per tag.** Everything for `MDS4a` lives in `<workroot>/MDS4a/`.
The workroot is `$MDS_WORKROOT` if set, otherwise the current directory, or
`--workroot DIR`. Nothing is created or deleted outside that directory, apart
from SAM, tape and `poms_map`, and those only in `publish` and
`digireco --install`.

**One manifest per tag.** `MDS4a/manifest.env` is a sourceable `key="value"`
file. `init` writes the configuration with the same keys as Stage 1's
`<TAG>.txt`, together with the release and version, DB purpose and version,
Musings versions, the names of every dataset the campaign will produce, POT, the
duty factor and the expected yields. Later steps add the input datasets they
picked, the tarball name, the job count and the index definition. All of them
read their settings from the manifest. The version letters (`ax`) are given once,
to `init`.

**Step markers.** Each step records `step_<name>_done` in the manifest. A step
refuses to run before the one it depends on and skips itself if already done.
`--force` overrides both. `build` refuses after `publish`, because the tarball on
tape would no longer match. A lock stops two steps from running on the same tag
at once. All output is also written to `MDS4a/run_logs/<step>-<time>.log`.

**Outward-facing actions are safe to rerun.** `publish` checks SAM before each
declare, upload and add-location, and only copies into `poms_map` when the file
there is missing or identical. Use `--force` to replace a different file. If the
step fails partway through, run it again. `--dry-run` prints every action
without doing it. This also applies to the index definition in `build`.

## Workdir layout

```
MDS4a/
  manifest.env                  config, yields, dataset names, step state
  run_logs/                     output of every mds.sh run
  lists/                        full and chosen file lists per input dataset
  filenames_<label>             paths read by make_template_fcl.py
  filenames_<label>_<N>.txt     the same files as SAM names, for mu2ejobdef
  SamplingInput_sr*.fcl  cnf.*.ensemble.*.tar  cnf.*-info.*.txt  *.json
  MDC2025-MDS4a.json            ensemble campaign  (copied to poms_map)
  MDC2025-MDS4a-stages.json     digi / reco / ntuple stages
  make_template.out             make_template_fcl.py output (expected dts yields)
  validate.txt  validate.csv  validate.pdf    validate report, per-job table, plots
  livetime.txt                  livetime actually built (ensemble_livetime.py)
  signal/<label>/               one signal set (default label <signal>_<rate>)
    signal.env  signal_all.txt  known_all.txt
    pe_<i>/  splitter.fcl ntuple.fcl *.log  mixed_files.txt  merged/  merged_list.txt
```

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
- `build` also warns when the chosen N files hold fewer generated events than
  the expected yield, not only the whole dataset.
- `publish` declares and uploads only its own two files. It no longer runs
  `ls *.json` / `ls *.tar`. It also copies the config into the tag-info file
  rather than moving it, so later steps can still read it.
- `validate` runs `../plot_ensemble_validation.py --check` on the logs where
  they are on pnfs. It compares each process's sampled fraction with its FCL
  weight, and each total with the expected **dts** yield (generated-level
  yield × dts efficiency, which `build` records as `dts_expected_<label>` and
  `sample_target`). Stage 4 only summed the counts. It also reports which input
  ran out and ended each job, and writes plots to `validate.pdf`. It never
  deletes files. The same script works on its own for tags made with the
  Stage scripts.
- `validate` then records the livetime that was actually built,
  `true_onspilltime` = requested × (events built / sampled target), with
  `true_beam_livetime` and `true_beam_npot`, in the manifest and `livetime.txt`.
  Events built come from SAM when `samweb` is set up, otherwise from the logs.
  `../ensemble_livetime.py` also gives a per-process estimate (N_i / E_i) as a
  cross-check, and works on its own with `--livetime` and `--stage2-log`.
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
- `--seed` makes the signal yield and every file shuffle reproducible.
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

## Testing

Run `MOCK=... PATH=<mock bin>:$PATH ENSEMBLE_PY=<mock> POMS_MAP=<tmp> mds.sh ...`
to exercise the logic without SAM or the grid. `ENSEMBLE_PY`, `POMS_MAP`, `MDS_LOG_ROOT` and `MDS_PYTHON` can
all be overridden from the environment for this.

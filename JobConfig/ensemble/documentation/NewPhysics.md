## 🧪 Introducing Signal: `mds.sh signal` and `mds.sh mix` (Stages 5 and 6)

`signal` injects a signal sample at a chosen $R_{\mu e}$ into the known-physics MDS, making one or more pseudo-experiments; `mix` merges each pseudo-experiment into the final ntuples. They replace `Stage5_signal.sh` and `Stage6_blind_and_mix.sh`. For a walk-through, see the [tutorial](MakeSignalMDS_tutorial.md).

## **1. `mds.sh signal`**

| Component | Description |
| :--- | :--- |
| **Purpose** | For each of `--nexp` pseudo-experiments, draw the number of signal events for the chosen livetime and $R_{\mu e}$, split that many reconstructed signal events off a signal sample, make their ntuple, and list it with a random choice of known-physics ntuples. |
| **Prerequisites** | `mds.sh digireco` for this tag, and the MDS ntuples in SAM. `samweb`, `mu2eDatasetFileList`, `samDatasetsSummary.sh`, `mu2e` and `python3` in PATH. The splitter and ntuple jobs run locally with your `mu2e`: set up the same EventNtuple as the MDS ntuples (see [Known limitations](#4-known-limitations)). |
| **Outcome** | `signal/<label>/pe_<i>/mixed_files.txt` for each pseudo-experiment, ready for `mix`. |

### **Usage**

```bash
mds.sh signal --tag <TAG> --signal <name> [--signalmcs <dataset>] [options]
mds.sh signal --tag MDS4b --signal CeMLeadingLog --rate 1e-13 --nexp 1 --seed 1 --livetime 2419200
```

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--signal` | (required) | Signal process, e.g. `CeMLeadingLog`. The digi mode (`OnSpill` or `Mix<N>BB`) is taken from the MDS unless the name includes one; add `Triggered` to prefer triggered samples. |
| `--signalmcs` | found in SAM | Reconstructed signal dataset `mcs.mu2e.<name>.<release>_<purpose>_<version>.art`. |
| `--rate` | `1e-13` | $R_{\mu e}$. |
| `--nexp` | `1` | Number of pseudo-experiments. |
| `--livetime` | all | Use only this many seconds of the known-physics livetime (rounded to whole ntuple files). |
| `--recoeff` | `0.4009075` | Signal reconstruction efficiency correction applied to the drawn yield. |
| `--merge` | `1` | mcs files per known-physics ntuple file (the ntuple stage's merge). |
| `--seed` | none | Makes the signal yields and every file choice reproducible; pseudo-experiment $i$ uses seed + $i$. |
| `--label` | `<signal>_<rate>` | Output directory `signal/<label>/`. Different labels can live side by side. |
| `--mdsfiles` | manifest `ds_nts` | Known-physics ntuple dataset. |
| `--dts-nfiles` | from SAM | Files in the MDS dts dataset, which sets the livetime per ntuple file. |
| `--signal-ngen` | from SAM | Generated events in the signal dataset. |
| `--owner` | manifest `owner` | Owner field of the local output names. |
| `--force` | off | Redo an existing label. |

### **Execution Flow**

#### **Signal dataset**

Without `--signalmcs`, `signal` lists `mcs.mu2e.<signal>%.<release>%.art` in SAM and keeps the candidates with the MDS's release and digi mode. They are ranked by: same DB purpose/version as the MDS, the `Triggered` preference, same SimJob version, then the latest version. The first one with files is used. It warns when the release, DB version or digi mode differs from the MDS's (the pileup or calibrations would not match), and when the sample is not trigger-filtered. The outputs are named after the sample actually used, e.g. `CeMLeadingLogOnSpill`.

#### **[1/4] Livetime and known-physics files**

Each known-physics ntuple file holds the livetime of `digi_merge` × `--merge` dts files:

$$
\text{livetime per ntuple file} = \text{dts livetime} \times \frac{\text{digi\_merge} \times \text{merge}}{N_{\text{dts files}}}
$$

The dts livetime is `true_beam_livetime` from `validate` when the manifest has it, otherwise the requested `beam_livetime` (with a warning). Only the ntuple files that exist in SAM count, so files lost in digi/reco/ntuple reduce the available livetime. `--livetime` is rounded to a whole number of ntuple files, $N_{\text{known}}$; the on-spill livetime is that times the duty factor.

#### **[2/4] Signal sample**

The generated events and file count of the signal dataset (from SAM, or `--signal-ngen`) give the events per signal file.

#### **[3/4] File lists**

`signal_all.txt` and `known_all.txt` list every file of the two datasets.

#### **[4/4] Pseudo-experiments**

For each pseudo-experiment $i$:

1.  **Signal yield:** `lib/yields.py signal` draws $N$ from a Poisson distribution with the mean for the on-spill livetime and $R_{\mu e}$ (`ce_normalization` in [Normalizations](Normalizations.md)); the number of signal events is $N \times$ `--recoeff`, rounded. It is recorded as `nsig_<i>` in `signal.env`.
2.  **Split:** enough signal files to hold them are chosen at random, and `mu2e -c splitter.fcl` (including `Production/JobConfig/ensemble/fcl/split.fcl`, with `source.maxEvents` set to the yield) writes `mcs.<owner>.<signal>Split.<dsconf>.<i>.art`.
3.  **Ntuple:** `mu2e -c ntuple.fcl` (including `EventNtuple/fcl/from_mcs-mockdata.fcl`) writes `nts.<owner>.<signal>Split.<dsconf>.<i>.root`.
4.  **Mixed list:** the signal ntuple and $N_{\text{known}}$ randomly chosen known-physics ntuples are shuffled into `pe_<i>/mixed_files.txt`.

Both `mu2e` jobs are checked for their exit status and output file. A pseudo-experiment with no signal events skips them and lists known physics only.

### **Output**

```
signal/<label>/
  signal.env          signal dataset, Rmue, livetime_combined, onspill_combined, recoeff,
                      known_files_per_pe, seed, nsig_<i>
  signal_all.txt  known_all.txt
  pe_<i>/
    signal_files.txt  splitter.fcl  ntuple.fcl  splitter.log  ntuple.log
    mcs.<owner>.<signal>Split.<dsconf>.<i>.art
    nts.<owner>.<signal>Split.<dsconf>.<i>.root
    mixed_files.txt
```

## **2. `mds.sh mix`**

| Component | Description |
| :--- | :--- |
| **Purpose** | Merge each pseudo-experiment's `mixed_files.txt` with `hadd`, a few files at a time, into the final ntuples. |
| **Prerequisites** | `mds.sh signal` for the label. `hadd` in PATH. |
| **Outcome** | `signal/<label>/pe_<i>/merged/*.root`, listed in `pe_<i>/merged_list.txt`. |

```bash
mds.sh mix --tag <TAG> [--label NAME] [--pe N|all] [--files-per-merge 2] [--force]
```

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--label` | the only signal set | Which signal set; required when there is more than one. |
| `--pe` | `all` | Merge one pseudo-experiment, or all. |
| `--files-per-merge` | `2` | Input files per merged file. |
| `--force` | off | Redo a pseudo-experiment that already has a `merged_list.txt`. |

Each group is merged with

```bash
hadd -f -k merged/<outname>_<n>.root <files>        # log in merged/hadd_<n>.log
```

(`-f` overwrites the output, `-k` skips corrupt or missing input files.) The output names are

$$
\text{nts.mu2e.ensemble}\mathbf{TAG}\text{Mix}\mathbf{BB}\_\mathbf{signal}\_\mathbf{Rmue}\_\mathbf{livetime}.\mathbf{i}\_\mathbf{n}\text{.root}
$$

e.g. `nts.mu2e.ensembleMDS4bMix1BB_CeMLeadingLogOnSpill_1e-13_2479260.1_1.root`, where the livetime is `livetime_combined` in seconds. Unlike `Stage6_blind_and_mix.sh`'s name suggests, no blinding is done (see below).

## **3. Checking the mixed sample**

`../scripts/plot_mix_validation.py` compares a signal set with the MDS it was drawn from. The expected known physics is the MDS after the analysis cuts × (known events in the mix / MDS events), and the expected signal is the signal ntuple after the same cuts. It plots momentum and t0 after cuts, the cut flow and the injected signal, and writes a report. It needs only numpy, pandas, scipy and matplotlib, but its inputs come from pyfitter's selection:

```bash
cd pyfitter; source python.sh
# the MDS itself, once (e.g. validate_MDS.py process --mds MDS4b), then per signal set:
python process.py --nofit --version run1a --loc local --file <known ntuples>.txt --outdir <dir>
python process.py --nofit --version run1a --loc local --file <signal ntuple>.txt --outdir <dir>
# add the two results (parquet rows and cut-flow counts) into <name>_mixsum, then:
plot_mix_validation.py --mix-dir <dir> --mix <name>_mixsum --sig <signal name> \
    --ref-dir MDS4b_run1a --ref MDS4b --out <dir>/validation
```

Run the selection on the files in `pe_<i>/mixed_files.txt` rather than the merged files, with the signal ntuple processed on its own; the script's docstring explains why. For MDS4b + CeMLeadingLog at $10^{-13}$ (2.48e6 s), 219 events pass the cuts against 212 expected, 73 of them signal.

## **4. Known limitations**

- **EventNtuple version of the signal ntuple.** `signal` makes the signal ntuple with whatever EventNtuple is set up, not the manifest's `anaversion`. If it differs from the MDS ntuples', `hadd` takes the first file's tree layout: branches only the signal has are dropped, and classes that changed without a version bump (e.g. `SimInfo`, `MCStepInfo` between EventNtuple v6.15 and v6.16) leave `trkmcsim` and `trkmcvd` unreadable by uproot in every merged file. The reconstructed quantities (`trk`, `trksegs`, `trkqual`, `trkpid`, `crvcoincs`) are unaffected.
- **Signal events are not blinded.** The signal ntuple keeps its own run, subrun and event numbers (for MDS4b, all in subrun 416, which no known-physics event uses) and its own DB version.
- **Livetime without `validate`.** If the manifest has no `true_beam_livetime`, the livetime is overstated by the built/target fraction (2.6% for MDS4b) and the signal yield is too high by the same amount.

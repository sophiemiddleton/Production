# Tutorial: making a signal MDS

This takes an existing known-physics MDS (one that has been through `mds.sh digireco` and whose ntuples are in SAM) and makes signal-mixed ntuples from it. The commands are from MDS4b with CeMLeadingLog at $R_{\mu e} = 10^{-13}$. For the details of each step, see [Introducing Signal](NewPhysics.md).

0. **Environment.** Set up the tools, and the same Analysis musing as the MDS ntuples, so the signal ntuple has the same EventNtuple version (the manifest's `anaversion`):

```bash
mu2einit
# the setup the MDS's ntuple stage used: Musings/Analysis<release>/<anaversion> from the manifest
source /cvmfs/mu2e.opensciencegrid.org/Musings/AnalysisMDC2025/v02_02_00/setup.sh
```

`samweb`, `mu2eDatasetFileList`, `samDatasetsSummary.sh`, `mu2e` and `hadd` must be in PATH; `signal` and `mix` check.

1. **Find the MDS's workroot**, the directory that holds `<TAG>/manifest.env`, and either `cd` there or pass `--workroot` to every command. Check the tag is ready:

```bash
cd /exp/mu2e/data/users/mu2epro/ensembles/MDS4
mds.sh status --tag MDS4b
```

`validate` should be done in this workroot, so the manifest has `true_beam_livetime`; otherwise `signal` warns and uses the requested livetime.

2. **Make the signal set:**

```bash
mds.sh signal --tag MDS4b --signal CeMLeadingLog --rate 1e-13 --nexp 1 --seed 1 --livetime 2419200
```

* `--signal`: the signal process; `signal` finds a compatible `mcs` dataset in SAM and prints which one it used (or pass `--signalmcs`)
* `--rate`: $R_{\mu e}$
* `--nexp`: how many pseudo-experiments (independent random samplings) to make
* `--seed`: makes the yields and file choices reproducible
* `--livetime`: seconds of known-physics livetime to use; it is rounded to whole ntuple files and capped at what is available

The output is in `MDS4b/signal/CeMLeadingLog_1e-13/`: `signal.env` records the dataset, livetime and number of signal events of each pseudo-experiment, and each `pe_<i>/` holds the split signal `mcs` and `nts` files, the FCLs and logs, and `mixed_files.txt`, the shuffled list of the signal ntuple and the known-physics ntuples. Read the warnings it prints: a different DB version, digi mode or release than the MDS, an untriggered signal sample, or a missing `true_beam_livetime`.

3. **Merge** every pseudo-experiment:

```bash
mds.sh mix --tag MDS4b
```

(`--label` is needed only when there is more than one signal set.) Each `pe_<i>/merged/` then holds files such as

```
nts.mu2e.ensembleMDS4bMix1BB_CeMLeadingLogOnSpill_1e-13_2479260.1_1.root
```

i.e. `ensemble<TAG>Mix<BB>_<signal>_<Rmue>_<livetime in s>.<pseudo-experiment>_<n>`, listed in `pe_<i>/merged_list.txt`. Change the merge factor with `--files-per-merge`.

4. **Check it** with `plot_mix_validation.py` ([Checking the mixed sample](NewPhysics.md#3-checking-the-mixed-sample)).

5. **Use it.** Analyze `merged_list.txt` as you would any other file list. For remote or xrootd access you would need to upload the files to SAM; keeping them in your own area is usually enough. Note that the signal events are not blinded (they keep their own subrun), and see the other [known limitations](NewPhysics.md#4-known-limitations).

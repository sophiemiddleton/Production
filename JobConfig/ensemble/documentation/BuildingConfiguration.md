## ⚙️ Building your Configuration: `mds.sh init` (Stage 1)

### **1. Overview**

`mds.sh init` starts a new Mock Data Sample (MDS) tag. It replaces `Stage1_initiate_ensemble.sh`. It:

1.  **Chooses the cosmics:** finds the latest `dts.mu2e.CosmicSignal.<release><letters>.art` (or uses `--cosmics`), lists its files sorted by name and keeps the first `--njobs` (default: all of them). The number of cosmic files sets the number of ensemble jobs.
2.  **Sets the livetime:** the on-spill livetime is `--livetime` [s], or `--compute-livetime` sums `printCosmicLivetime` over the chosen files.
3.  **Computes POT and the expected yields** with `lib/yields.py`, which calls the same `normalizations.py` functions as `calculateEvents.py` (see [Normalizations](Normalizations.md)).
4.  **Writes the manifest** `<workroot>/<TAG>/manifest.env`, a shell-sourceable `key="value"` file that every later step reads and adds to. It holds the configuration (same keys as Stage 1's old `<TAG>.txt`), the release and version, DB purpose and version, the SimJob setup and Analysis version, the names of every dataset the campaign will produce, POT, the duty factor and the expected yields.

See [scripts/new/README.md](../scripts/new/README.md) for how the steps fit together.

### **2. Usage**

```
mds.sh init --tag <TAG> --version <letters> --livetime <s> [options]
mds.sh init --tag MDS4a --version ax --livetime 5.72e6 --type physics --BB 1BB
```

Set up muse and mu2einit first, so that `samweb`, `mu2eDatasetFileList` and `python3` are in PATH (and `mu2e` for `--compute-livetime`). The tag directory is created under `--workroot DIR`, else `$MDS_WORKROOT`, else the current directory. `init` refuses to overwrite an existing manifest unless `--force`.

### **3. Arguments**

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--tag` | (required) | MDS tag, letters and digits only, e.g. `MDS4a`. |
| `--version` | (required) | SimJob version letters, e.g. `ax`, giving `MDC2025ax`. Set once here; every later step takes it from the manifest. |
| `--livetime` | (required, or `--compute-livetime`) | On-spill cosmic livetime [s] of the chosen cosmic files (see the [MDC2025 wiki](https://mu2ewiki.fnal.gov/wiki/MDC2025#Cosmics)). |
| `--compute-livetime` | off | Sum `printCosmicLivetime` over the chosen files instead. Resampled cosmics carry the `CosmicLivetime` integer-division bug. |
| `--release` | `MDC2025` | Release prefix of every dataset name. |
| `--type` | `physics` | `physics` (DIO $E_{\text{min}}$ 95 MeV) or `trigger` (75 MeV). |
| `--BB` | `1BB` | Beam mode, `1BB` or `2BB`; sets the duty factor (0.323 or 0.246) and POT. |
| `--tmin` | `350` | RPC time cut [ns]. |
| `--njobs` | all cosmic files | Number of cosmic files, i.e. ensemble jobs. If fewer than all, `--livetime` must be the livetime of those files. |
| `--cosmics` | latest `dts.mu2e.CosmicSignal` | Cosmics dataset version, e.g. `MDC2025ac`. |
| `--stops` | `MDC2025ac` | Muon-stops version. |
| `--rmcn0` / `--rmcn1` | `1` / `0` | Include RMC 0N / 1N (1N is off until its samples are fixed). |
| `--rpc-emin` | `50` | RPC $E_{\text{min}}$ [MeV]. |
| `--rmc-n0-emin` / `--rmc-n1-emin` | `80` / `80` | RMC 0N / 1N $E_{\text{min}}$ [MeV]. |
| `--rmc-kmax` | `90.1` | RMC $k_{\text{max}}$ [MeV]. |
| `--ipa-emin` | `70` | IPA Michel $E_{\text{min}}$ [MeV]. |
| `--owner` | `mu2e` | Owner of the datasets and the tag-info file. |
| `--run` | `1430` | Run number of the ensemble. |
| `--samplingseed` | `1` | SamplingInput seed. |
| `--dbpurpose` / `--dbversion` | `Sim_best` / `v1_1` | DB used by digi/reco; gives `best_v1_1` in the dataset names. |
| `--anaversion` | `v02_02_00` | `Musings/Analysis<release>/<anaversion>`, used for the ntuple stage. |
| `--ntuple-dsconf` | `<release>-001` | Ntuple dsconf prefix; the dataset is `nts.mu2e.ensembleNtuple.<prefix>_<TAG>.root`. |

### **4. Expected yields**

`lib/yields.py background` writes these keys to the manifest (all for the on-spill livetime):

| Key | Process | Cut |
| :--- | :--- | :--- |
| `beam_onspill_time`, `beam_livetime`, `duty_factor` | on-spill and total livetime | `beam_livetime` = on-spill / duty factor |
| `beam_npot`, `beam_pot`, `beam_nmot` | **Protons on target**, and stopped muons | |
| `dio_events` | **Decay in orbit** | $E > $ `DEM_emin` |
| `ipa_events` | **IPA Michel** | $E > $ `IPA_emin` |
| `rpc_internal_events`, `rpc_external_events` | **Radiative pion capture**, internal / external conversion | $E > $ `RPC_emin`, $t > $ `RPC_TMIN` |
| `rmc_n0_internal_events`, `rmc_n0_external_events` | **Radiative muon capture**, 0N (with `--rmcn0 1`) | $E > $ `RMC_N0_emin` |
| `rmc_n1_internal_events`, `rmc_n1_external_events` | **Radiative muon capture**, 1N (with `--rmcn1 1`) | $E > $ `RMC_N1_emin` |

These are generated-level yields. `build` later records the expected **dts** yields (generated-level yield × dts filter efficiency) that `validate` checks against.

### **5. Output**

```
<TAG>/manifest.env           configuration, dataset names, POT, yields, step_init_done
<TAG>/lists/CRYCosmic.*      all, sorted and chosen cosmic files (and .livetime with --compute-livetime)
<TAG>/run_logs/init-*.log    output of the run
```

Next: `mds.sh build --tag <TAG>` ([Building Known Physics](BuildingKnownPhysics.md)).

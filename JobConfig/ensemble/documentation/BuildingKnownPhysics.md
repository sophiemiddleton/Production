## 🚀 Building Known Physics: `mds.sh build` (Stage 2)

### **1. Overview**

`mds.sh build` prepares the ensemble (known physics) grid job. It replaces `Stage2_build_sampler.sh`. It does not submit anything: the job runs as a POMS campaign after `publish` ([Running with the Grid](UploadToTape.md)).

| Component | Description |
| :--- | :--- |
| **Purpose** | Find an input dataset for each process, make the per-process file lists, generate the SamplingInput template FCL, build the `mu2ejobdef` tarball and create its SAM index definition. |
| **Prerequisites** | `mds.sh init` for this tag. `samweb`, `mu2eDatasetFileList`, `samDatasetsSummary.sh`, `mu2ejobdef` and `mu2ejobquery` in PATH. |
| **Outcome** | `cnf.<owner>.ensemble.<release><version>_<TAG>.0.tar`, its index definition `idx_<owner>.ensemble.<release><version>_<TAG>`, and the expected dts yields in the manifest. |

### **2. Usage**

```
mds.sh build --tag <TAG> [--pin LABEL=VERSION ...] [--dry-run] [--force]
mds.sh build --tag MDS4a
mds.sh build --tag MDS4a --pin DIO=au --pin RPCExternal=av
```

Every setting (release, version, cuts, number of jobs, SimJob setup, run, seed) comes from the manifest written by `init`. `build` skips itself if already done, and refuses after `publish`, because the tarball on tape would no longer match; `--force` overrides both. `--dry-run` prints the index definition instead of creating it, and does not mark the step done.

| Argument | Description |
| :--- | :--- |
| `--pin LABEL=VERSION` | Use version letters `VERSION` for one process instead of the latest in SAM. `LABEL` is one of `DIO`, `RPCInternal`, `RPCExternal`, `IPAMichel`, `RMCPhaseSpace0NInternal`, `RMCPhaseSpace0NExternal`, `RMCPhaseSpace1NInternal`, `RMCPhaseSpace1NExternal`. |

### **3. Execution Flow**

#### **[1/6] Input dataset versions**

Each process is looked up in SAM on its own, as `<prefix>.<release>%.art`, and the latest version letters are used: letters are sorted by length and then alphabetically, so `aa` is later than `z`. A failed lookup stops the step; pin it with `--pin`. The choice is recorded as `input_ds_<label>`.

| Label | Dataset | File location |
| :--- | :--- | :--- |
| `DIO` | `dts.mu2e.DIOtail<DEM_emin>.<release><v>.art` | default |
| `CRYCosmic` | `dts.mu2e.CosmicSignal.<CosmicJob>.art` (files chosen in `init`) | |
| `RPCInternal` | `dts.mu2e.RPCInternalPhysical.<release><v>.art` | `--tape` |
| `RPCExternal` | `dts.mu2e.RPCExternalPhysical.<release><v>.art` | default |
| `RMCPhaseSpace0NInternal/External` | `dts.mu2e.RMCPhaseSpace0N{Internal,External}.<release><v>.art` (if RMC 0N is on) | default |
| `RMCPhaseSpace1NInternal/External` | `dts.mu2e.RMCPhaseSpace1N{Internal,External}.<release><v>.art` (if RMC 1N is on) | default |
| `IPAMichel` | `dts.mu2e.IPAMuminusMichel.<release><v>.art` | `--tape` |

#### **[2/6] Files and generated events**

For each process, `mu2eDatasetFileList` lists the files at that location, sorted by name, and the first `njobs` are chosen. The step stops if a dataset has fewer files than jobs, if SAM gives no generated-event count, if the manifest has no expected yield, or if the dataset has fewer generated events than the expected yield. It warns when the chosen files alone probably hold fewer generated events than the expected yield.

#### **[3/6] File lists**

`filenames_<label>` (paths, read by `make_template_fcl.py`) and `filenames_<label>_<njobs>.txt` (the same files as SAM names, for `mu2ejobdef`) come from the same sorted list, so both see the same files in the same order.

#### **[4/6] Template FCL**

```bash
make_template_fcl.py --BB=<BB> --release=<release><version> --tag=<TAG> --livetime=<onspilltime> \
  --run=<run> --dioemin=... --rpcemin=... --rmcn0emin=... --rmcn1emin=... --rmckmax=... --ipaemin=... \
  --tmin=<RPC_TMIN> --samplingseed=<samplingseed> --prc <labels>
```

This writes `SamplingInput_sr0.fcl`, which sets the weight each process is sampled with. Its output is saved in `make_template.out`. From it, `build` records the expected dts yield of each process (`dts_expected_<label>`: generated-level yield × dts filter efficiency) and the total number of events to sample (`sample_target`), which `validate` checks against.

#### **[5/6] Job tarball**

```bash
mu2ejobdef --desc=ensemble --dsconf=<release><version>_<TAG> --run=<run> --setup <simjob_setup> \
  --sampling=1:<label>:filenames_<label>_<njobs>.txt ... --embed SamplingInput_sr0.fcl --verb
```

`mu2ejobdef` packages the FCL, the SimJob setup and the input file lists into `cnf.<owner>.ensemble.<dsconf>.0.tar`. The `--sampling` arguments tell SamplingInput which file list each process draws from. `mu2ejobquery --njobs` gives the number of jobs; it should equal `njobs`.

#### **[6/6] Index definition**

```bash
samweb create-definition idx_<owner>.ensemble.<dsconf> "dh.dataset etc.mu2e.index.000.txt and dh.sequencer < <njobs>"
```

An existing definition is left alone.

### **4. Output**

```
<TAG>/lists/                      all, sorted and chosen file lists per process
<TAG>/filenames_<label>           paths read by make_template_fcl.py
<TAG>/filenames_<label>_<N>.txt   the same files as SAM names, for mu2ejobdef
<TAG>/SamplingInput_sr*.fcl       template FCL
<TAG>/make_template.out           make_template_fcl.py output (expected dts yields)
<TAG>/cnf.*.ensemble.*.0.tar      job tarball
manifest.env                      + input_ds_<label>, dts_expected_<label>, sample_target,
                                    tarball, jobdef_njobs, index_def, step_build_done
```

Next: `mds.sh publish --tag <TAG> --dry-run`, then without `--dry-run` ([Running with the Grid](UploadToTape.md)).

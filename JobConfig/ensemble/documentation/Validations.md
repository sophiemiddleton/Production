## 🔍 Validations: `mds.sh validate` (Stage 4)

### **1. Overview**

After the ensemble campaign, `mds.sh validate` checks that the sampling did what the template FCL asked for, and records the livetime that was actually built. It replaces `Stage4_validate_dts.sh`, which only summed the counts in the logs.

| Component | Description |
| :--- | :--- |
| **Purpose** | Compare the events each job sampled with the FCL weights and the expected dts yields; work out the livetime the ensemble actually contains. |
| **Input** | The ensemble job logs, read in place from the log dataset on pnfs: `${MDS_LOG_ROOT:-/pnfs/mu2e/persistent/datasets/phy-etc/log}/<owner>/ensemble/<dsconf>/log` (or `--logs DIR`). |
| **Output** | `validate.txt` (report), `validate.csv` (per job, per process), `validate.pdf` (plots), `livetime.txt`, and the true livetime in the manifest. |
| **Tools** | `../scripts/plot_ensemble_validation.py` and `../scripts/ensemble_livetime.py`, which also work on their own. The plots need matplotlib: `$MDS_PYTHON`, by default the Mu2e ana environment's `python3`. |

### **2. Usage**

```
mds.sh validate --tag <TAG> [--logs DIR] [--nsigma 5] [--no-plots] [--accept]
```

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--logs` | the log dataset on pnfs | Read the logs from another directory. |
| `--nsigma` | `5` | Threshold for the checks below. |
| `--no-plots` | off | Tables only, no PDF. |
| `--accept` | off | Record the step as done even when a check fails. |

`validate` needs `publish` to have been done and can be rerun. A failed check stops the step unless `--accept`.

### **3. What is checked**

Each job log has a SamplingInput table: per process, the sampled count, the sampled and expected fractions, the weight, and the next event or `(no more available)` for the input that ran out and ended the job. `plot_ensemble_validation.py --check` reads every log and fails when:

- a process's sampled fraction over all jobs is more than `--nsigma` from its weight in `SamplingInput_sr0.fcl`
- logs have no table, or there are fewer jobs than the tarball defines
- a process is more than `--nsigma` Poisson sigmas from its expected dts yield (`dts_expected_<label>`, generated-level yield × dts filter efficiency, recorded by `build`), or the total is more than `--nsigma` from the sampled target (`sample_target`)

It warns when the per-job pull RMS is far from 1, or when an input other than the usual limiting one ends more than 1% of jobs. The pages of `validate.pdf`:

1. per-process sampled fraction over all jobs vs the configured fraction (pull)
2. per-job sampled fraction, with the FCL weight
3. per-job pulls, which should be unit Gaussians
4. events per job, and which input ran out to end each job
5. events per job vs job index (spots bad or short input files)
6. sampled vs expected dts yield per process, and the total vs the target

### **4. The livetime actually built**

Jobs end when one input runs out, so the ensemble usually holds a little less than the requested livetime. `validate` runs `ensemble_livetime.py` on `validate.csv` and records in the manifest (and `livetime.txt`):

$$
\text{true\_onspilltime} = \text{requested on-spill time} \times \frac{\text{events built}}{\text{sampled target}}
$$

with `true_beam_livetime`, `true_beam_npot` and `true_fraction`. Events built is the dts dataset's count in SAM when `samweb` is set up, otherwise the sum over the logs. `ensemble_livetime.py` also prints a per-process estimate ($N_i / E_i$) as a cross-check. For MDS4b the fraction was 0.9735.

`signal` uses `true_beam_livetime` for the livetime per ntuple file. Run `validate` in the same workroot before `signal`; otherwise `signal` falls back to the requested livetime and injects too much signal by the same fraction.

### **5. Running the scripts on their own**

Both scripts work without `mds.sh`, e.g. for tags made with the old Stage scripts:

```bash
plot_ensemble_validation.py --logs <log dir> --stage2-log <make_template_fcl.py output> --out MDS4a_validation --check
plot_ensemble_validation.py --from-csv MDS4a_validation.csv --out MDS4a_validation
ensemble_livetime.py --from-csv MDS4a_validation.csv --livetime 5.72e6 --stage2-log <make_template_fcl.py output> --sam
ensemble_livetime.py --from-csv validate.csv --manifest manifest.env --env
```

Run either with `--help` for all options.

### **6. Further checks**

- After `digireco` and the POMS stages, `mds.sh status --tag <TAG>` shows the file counts of the dts, dig, mcs and nts datasets.
- pyfitter's `validate_MDS.py` compares the MDS ntuples after the analysis cuts with the scaled MC (data vs MC total, momentum and t0).
- For a signal-mixed sample, see [Checking the mixed sample](NewPhysics.md#3-checking-the-mixed-sample).
- `logchecker.py` and `plot_log_stats.py` are the older tools for the SamplingInput tables; `plot_ensemble_validation.py` replaces them.

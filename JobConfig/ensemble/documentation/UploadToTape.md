# 📤 Running with the Grid: `mds.sh publish` and `mds.sh digireco` (Stage 3)

`publish` archives the ensemble job and installs its campaign JSON; `digireco` writes the digi / reco / ntuple stages that run on the ensemble's output. They replace `Stage3_configure_ensemble_campaign.sh` and its `--append` mode. The POMS campaigns run between them:

```
mds.sh publish  --tag <TAG> --dry-run      # check first
mds.sh publish  --tag <TAG>
    ── POMS: ensemble campaign (mkidxdef + launch, as mu2epro) ──
mds.sh validate --tag <TAG>                # see Validations.md
mds.sh digireco --tag <TAG>
    ── POMS: json2jobdef for digi / reco / ntuple, relaunch ──
```

## **1. `mds.sh publish`**

| Component | Description |
| :--- | :--- |
| **Purpose** | Declare the job tarball and the tag-info file to SAM, upload them, register their locations, and write the ensemble campaign JSON into `poms_map`. |
| **Prerequisites** | `mds.sh build` for this tag. `samweb`, `printJson`, `mu2eFileDeclare` and `mu2eFileUpload` in PATH. Write access to `poms_map` (`/exp/mu2e/app/users/mu2epro/production_manager/poms_map`, or `$POMS_MAP`). |
| **Outcome** | Tarball and tag-info file in SAM with a location; `<release>-<TAG>.json` in `poms_map`. |

```
mds.sh publish --tag <TAG> [--dry-run] [--force]
```

These are the only actions (with `build`'s index definition and `digireco --install`) that change anything outside the tag directory, so run with `--dry-run` first: it prints every action without doing it. Each action first checks whether it was already done, so after a failure you simply run `publish` again. `publish` skips itself once done (`--force` to redo).

### **Execution Flow**

1.  **Job tarball** (`cnf.<owner>.ensemble.<dsconf>.0.tar`, from `build`):
    ```bash
    printJson --no-parents <file> > <file>.json        # unless SAM already has its metadata
    mu2eFileDeclare < <file>.json
    printf '%s\n' <file> | mu2eFileUpload --disk       # unless it already has a location
    samweb add-file-location <file> enstore:<directory from the upload output>
    ```
    Only this file is declared and uploaded; nothing else in the directory is touched.

2.  **Tag-info file** `cnf.<owner>.<TAG>-info.<release><version>.0.txt`: a copy of the manifest without the `step_*` lines, published the same way. It records the MDS configuration in SAM (pyfitter's `validate_MDS.py` reads it back).

3.  **Campaign JSON** `<release>-<TAG>.json`, copied to `poms_map` if it is not there or is identical; a different file there is only replaced with `--force`:
    ```json
    [
    {
        "tarball": "cnf.<owner>.ensemble.<dsconf>.0.tar",
        "njobs": <njobs>,
        "inloc": "disk",
        "outputs": [
          {
            "dataset": "*.art",
            "location": "tape"
          }
        ]
      }
    ]
    ```

## **2. The ensemble campaign in POMS**

`publish` prints these steps when it finishes. As mu2epro:

1. go to https://pomsgpvm02.fnal.gov/poms/index/mu2e/production
2. select `Campaigns`, choose the most recent MDS campaign and click the icon under `Clone Campaign`
3. name it clearly, e.g. `MDC2025_MDS4a`, and edit the parameters in the GUI editor
4. for the ensemble stage, SamplingInput needs `ifdh` rather than `xrootd`, so add to `param_overrides`:
   ```
   '-Oexecutable_1.arg_4=', '--copy-input'
   ```
   This is not needed for the later stages.
5. make the index definition for the jobs and launch from the GUI:
   ```bash
   mkidxdef --jobdefs <poms_map>/<release>-<TAG>.json --prod
   ```

The output is `dts.mu2e.ensemble.<release><version>_<TAG>.art`, with the job logs in `/pnfs/mu2e/persistent/datasets/phy-etc/log/<owner>/ensemble/<dsconf>/log`. `mds.sh status --tag <TAG>` shows the SAM file counts. When the campaign is done, run `mds.sh validate` ([Validations](Validations.md)).

## **3. `mds.sh digireco`**

| Component | Description |
| :--- | :--- |
| **Purpose** | Write `<release>-<TAG>-stages.json` with the digi, reco and ntuple stages, and print the `json2jobdef` commands that add them to the campaign. |
| **Prerequisites** | `mds.sh validate` for this tag. |
| **Outcome** | The stages JSON in the tag directory (and in `poms_map` with `--install`). |

```
mds.sh digireco --tag <TAG> [--digi-merge 100] [--install] [--jobdefs PATH] [--dry-run] [--force]
```

| Argument | Default | Description |
| :--- | :--- | :--- |
| `--digi-merge` | `100` | dts files per digi job (the value in the digi stage's `input_data`). `signal` later uses it to work out the livetime per ntuple file. |
| `--install` | off | Also copy the stages JSON into `poms_map` under its own name. It never overwrites `<release>-<TAG>.json`, which `Stage3 --append` did. |
| `--jobdefs` | `<poms_map>/<release>-<TAG>.json` | Jobdefs file in the printed `json2jobdef` commands. |

The three stages, with dataset names, DB purpose/version and Musings versions from the manifest:

| desc | FCL | Input | Output | Setup |
| :--- | :--- | :--- | :--- | :--- |
| `ensembleOnSpill` | `Production/JobConfig/digitize/OnSpill.fcl` | `dts.mu2e.ensemble.<dsconf>.art`, `--digi-merge` files per job | `dig.mu2e.ensembleOnSpill.<dsconf>_<db>.art` (tape) | `Musings/SimJob/<release><version>` |
| `ensembleOnSpillReco` | `Production/JobConfig/recoMC/OnSpill.fcl` | the dig dataset, 1 file per job | `mcs.mu2e.ensembleOnSpillReco.<dsconf>_<db>.art` (tape) | `Musings/SimJob/<release><version>` |
| `ensembleNtuple` | `EventNtuple/fcl/from_mcs-mockdata.fcl` | the mcs dataset, 1 file per job | `nts.mu2e.ensembleNtuple.<ntuple_dsconf>.root` (disk) | `Musings/Analysis<release>/<anaversion>` |

`<db>` is the DB purpose without `Sim_` plus the version, e.g. `best_v1_1`. Then, as mu2epro, run the printed commands and relaunch the campaign from the GUI:

```bash
json2jobdef --json <stages json> --dsconf <dsconf>_<db> --desc ensembleOnSpill     --jobdefs <jobdefs> --prod
json2jobdef --json <stages json> --dsconf <dsconf>_<db> --desc ensembleOnSpillReco --jobdefs <jobdefs> --prod
json2jobdef --json <stages json> --dsconf <ntuple_dsconf> --desc ensembleNtuple    --jobdefs <jobdefs> --prod
```

When the ntuples are in SAM, inject signal with `mds.sh signal` ([Introducing Signal](NewPhysics.md)).

# Mock Data Infrastructure

This directory contains all the utilities associated with Mock Data (ensemble) production. The workflow is driven by [`scripts/new/mds.sh`](scripts/new/README.md), one step per stage:

```
mds.sh init → build → publish → [POMS ensemble] → validate → digireco → [POMS digi/reco/ntuple] → signal → mix
```

# Documentation:

* [The mds.sh workflow](scripts/new/README.md) - how the steps fit together, the manifest, the workdir layout, known limitations
* [Building a Configuration](documentation/BuildingConfiguration.md) - `mds.sh init` (Stage 1): configuration and event yields
* [Building Known Physics](documentation/BuildingKnownPhysics.md) - `mds.sh build` (Stage 2): input lists, template FCL and job tarball
* [Running with the Grid](documentation/UploadToTape.md) - `mds.sh publish` and `digireco` (Stage 3): SAM, tape and the POMS campaigns
* [Validations](documentation/Validations.md) - `mds.sh validate` (Stage 4): checking the sampling and the livetime built
* [Introducing Signal](documentation/NewPhysics.md) - `mds.sh signal` and `mix` (Stages 5 and 6): mixing in signal, and checking the result
* [Normalizations](documentation/Normalizations.md) - the yield calculations in `python/normalizations.py`
* [Tutorial for End Ntuples](documentation/MakeSignalMDS_tutorial.md) - making signal-mixed ntuples from an existing MDS

The old `Stage0`–`Stage6` scripts were removed in commit `ef6db55d`; see the history before it.

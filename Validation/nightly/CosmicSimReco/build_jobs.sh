#
# nightly validation jobs for MDS
#
# S1 validation
# S2 validation
#Production/Scripts/nightly_jobs.sh --dir CosmicSimReco --script S2 --dataset sim.mu2e.CosmicDSStopsCORSIKA.MDC2020ab.art
# dts -> dig validation
Production/Scripts/nightly_jobs.sh --dir CosmicSimReco --script digitizeOnSpill --dataset dts.mu2e.CosmicCRYSignalAll.MDC2020ar.art
Production/Scripts/nightly_jobs.sh --dir CosmicSimReco --script digitizeOffSpill --dataset dts.mu2e.CosmicCORSIKASignalAll.MDC2020ar.art
# dig -> mcs(rec) validation
Production/Scripts/nightly_jobs.sh --dir CosmicSimReco --script reconstructOnSpill --dataset dig.mu2e.CosmicCORSIKASignalAllOnSpillTriggered.MDC2020au_best_v1_3.art
Production/Scripts/nightly_jobs.sh --dir CosmicSimReco --script reconstructOffSpill --dataset dig.mu2e.CosmicCRYSignalAllOffSpillTriggered.MDC2020ar_best_v1_3.art

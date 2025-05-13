#
# nightly validation jobs for MDS
#
# dts -> dig validation
Production/Scripts/nightly_jobs.sh --dir MDS --script digitize --dataset dts.mu2e.ensembleMDS1e.MDC2020ar.art
# dig -> mcs(rec) validation
Production/Scripts/nightly_jobs.sh --dir MDS --script reconstruct --dataset dig.mu2e.ensembleMDS1eMix1BBTriggered.MDC2020ai_perfect_v1_3.art

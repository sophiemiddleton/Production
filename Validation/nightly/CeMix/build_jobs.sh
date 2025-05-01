#
# nightly validation jobs for MDS
#
# dts -> dig validation
Production/Scripts/nightly_jobs.sh --dir ceSimReco --script digitize --dataset dts.mu2e.ensembleMDS1e.MDC2020ar.art
# dig -> mcs(rec) validation
Production/Scripts/nightly_jobs.sh --dir ceSimReco --script reconstruct --dataset dig.mu2e.CeEndpointOnSpillTriggered.MDC2020au_best_v1_3.art
Production/Scripts/nightly_jobs.sh --dir ceSimReco --script reconstruct --dataset dig.mu2e.CePlusEndpointOnSpillTriggered.MDC2020au_best_v1_3.art

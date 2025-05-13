#
# nightly validation jobs for Ce simulation and reconstruction
#
# dts -> dig validation
Production/Scripts/nightly_jobs.sh --dir CeSimReco --script digitize --dataset dts.mu2e.CeEndpoint.MDC2020ar.art
# dig -> mcs(rec) validation
Production/Scripts/nightly_jobs.sh --dir CeSimReco --script reconstructCeMinus --dataset dig.mu2e.CeEndpointOnSpillTriggered.MDC2020au_best_v1_3.art
Production/Scripts/nightly_jobs.sh --dir CeSimReco --script reconstructCePlus --dataset dig.mu2e.CePlusEndpointOnSpillTriggered.MDC2020au_best_v1_3.art

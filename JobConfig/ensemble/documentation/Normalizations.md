## ⚛️ Code Documentation: Mu2e Normalization Utility (`normalizations.py`)

This script is a set of Python utilities designed for normalizing a combined set of backgrounds (or known physics) contibutions for Mu2e. It focuses on calculating the expected normalization factors (event counts) for various background processes based on operational livetime, beam configuration/conditions and current understanding of the relative rates.

---

### **1. Overview & Dependencies**

| Component | Description |
| :--- | :--- |
| **Purpose** | Calculates expected event yields for key Mu2e physics processes (DIO, RMC, RPC, IPA Michel) based on simulation efficiencies and experiment parameters (POT, run time). |
| **Dependencies** | `DbService`, `argparse`, `ROOT`, `math`, `random`, `os`, `numpy` |
| **Domain** | For use in Mu2e Mock Data Production |

### **2. Global Constants & Rates**

The script defines global constants for fundamental physics interaction probabilities, primarily for muons and pions stopping in the target. These values are sourced from experimental (non-Mu2e) data and dedicated Mu2e simulations.

| Group | Constant | Value | Description |
| :--- | :--- | :--- | :--- |
| **Muon** | `CAPTURES_PER_STOPPED_MUON` | $0.609$ | Fraction of stopped $\mu^-$ that undergo nuclear capture. |
| | `DIO_PER_STOPPED_MUON` | $0.391$ | Fraction of stopped $\mu^-$ that decay in orbit ($\mu \to e \nu \bar{\nu}$). |
| | `RMC_GT_57_PER_CAPTURE` | $1.43 \times 10^{-5}$ | Rate of Radiative Muon Capture ($\mu \to \gamma \nu \bar{\nu}$) producing a $\gamma > 57 \text{ MeV}$ per capture. |
| **Pion** | `RPC_PER_STOPPED_PION` | $0.0215$ | Fraction of stopped $\pi^-$ that result in Radiative Pion Capture ($\pi \to \gamma$). |
| **Conversion** | `INTERNAL_PER_RMC` | $0.00690$ | Internal Conversion Ratio (electron/positron pair creation) for RMC. |
| | `INTERNAL_RPC_PER_RPC` | $0.00690$ | Internal Conversion Ratio for RPC. |

---

### **3. Database Initialization and Data Retrieval**

The initial block establishes a connection to a database (`DbService.DbTool`) to retrieve crucial **simulation efficiencies** and normalization factors specific to a run and version (e.g., `MDC2025_best`, `v1_1`, Run `1430`).

* **Database Query:** The script executes a query to the `SimEfficiencies2` table.
* **Data Extraction:** It parses the result (`rr`) to populate global variables:
    * `target_stopped_muons_per_pot`: Rate of stopped muons in the target per POT.
    * `target_stopped_pions_per_pot`: Rate of stopped pions in the target per POT.
    * `num_pion_stops`, `num_pion_filters`, `num_pion_resamples`, `selected_sum_of_weights`: Simulation event counts and weights used to calculate complex pion survival probabilities.
    * `ipa_stopped_mu_per_POT`: Rate of IPA muons per POT.

---

### **4. Core Normalization Functions**

The following functions calculate the expected event counts for each process, based on the total Protons on Target (POT) and process-specific efficiencies/rates.

#### **`get_duty_factor(run_mode='1BB')`**

Returns the fractional time the beam is *on* (duty factor) based on the accelerator's operational mode.

* **1BB (One Beam Batch):** `duty_factor = 0.323`
* **2BB (Two Beam Batches):** `duty_factor = 0.246`

#### **`get_pot(on_spill_time, run_mode='1BB', printout=False, frac=1)`**

Calculates the total number of Protons on Target (POT) for a given beam-on time.

$$
\text{Total POT} = \frac{\text{On-Spill Time}}{\text{Cycle Time } (T_{\text{cycle}})} \times \text{POT per Cycle}
$$

| `run_mode` | $\text{POT per Cycle}$ | $T_{\text{cycle}}$ |
| :--- | :--- | :--- |
| `'1BB'` | $4 \times 10^{12}$ | $1.33 \text{ s}$ |
| `'2BB'` | $8 \times 10^{12}$ | $1.4 \text{ s}$ |

#### **`ce_normalization(on_spill_time, rue, run_mode='1BB')`**

Calculates the expected number of **Conversion Electron (CE)** events (the signal).


* $\lambda$ (Mean Expected Events):

$$
\lambda = \text{Total POT} \times \frac{\mu_{\text{stopped}}}{\text{POT}} \times \frac{\mu_{\text{captured}}}{\mu_{\text{stopped}}} \times \text{RUE}
$$

Where $R_{\mu e}$ is the **conversion rate relative to capture**.

* **Result:** Samples the final event count from a **Poisson distribution** ($\text{np.random.poisson}(\lambda)$).

Note: this function is used only for signal injection (`mds.sh signal`, through `scripts/new/lib/yields.py signal`).

#### **`dio_normalization(on_spill_time, e_min, run_mode='1BB')`**

Calculates the expected **Decay In Orbit (DIO)** events above a minimum energy $E_{\text{min}}$.

* **Process:** Loads the DIO energy spectrum from an external file (`heeck_finer_binning...tbl`).
* **Energy Cut:** Determines the **fraction** of the spectrum above $E_{\text{min}}$.
* **Result:**

$$
N_{\text{DIO}} = \text{Total POT} \times \frac{\mu_{\text{stopped}}}{\text{POT}} \times \text{DIO}_{\text{rate}} \times \text{Fraction}(\text{E} > E_{\text{min}})
$$

#### **`rpc_normalization(on_spill_time, t_min, internal, e_min, run_mode='1BB')`**

Calculates expected **Radiative Pion Capture (RPC)** events, potentially including **Internal Conversion** (if `internal=1`).

* **Process:** Loads the RPC gamma energy spectrum (`rpcspectrum.tbl`).
* **Simulation Correction:** Applies complex correction factors derived from simulation globals: 

$$
\epsilon_{filter} = \frac{{N_{filters}}}{{N_{stops}}}
$$ 

(**filter efficiency**) 

and 

$$
\epsilon_{surv} = \frac{\sum_{i} w_{i}}{N_{piresample}}
$$ 

(**survival probability**).

* **Internal Conversion:** If enabled, scales the result by `INTERNAL_RPC_PER_RPC`.

#### **`rmc_normalization(on_spill_time, internal, e_min, k_max=90.1, run_mode='1BB')`**

Calculates expected **Radiative Muon Capture (RMC)** events, potentially including Internal Conversion.

* **Spectrum Generation:** The gamma energy spectrum is **generated internally** using the Closure Approximation formula: $\propto (1 - 2x + 2x^2) x (1 - x)^2$, where $x = E/K_{\text{max}}$.
* **Base Rate:** Uses the constant `RMC_GT_57_PER_CAPTURE`.
* **Internal Conversion:** If enabled, scales the result by `INTERNAL_PER_RMC`.

#### **`ipaMichel_normalization(on_spill_time, ipa_de_min, run_mode='1BB')`**

Calculates expected **IPA originating** Michel electrons above a minimum energy.

* **Process:** Loads an efficiency table (`ipa_spec_eff.tbl`) to find the fraction of events passing the energy cut (`ipa_de_min`).
* **Result:**

$$
N_{\text{IPA}} = \text{Total POT} \times \frac{\text{IPA}\mu_{\text{stopped}}}{\text{POT}} \times \text{IPA}_{\text{Decay Rate}} \times \text{Fraction}(\text{E} > E_{\text{min}})
$$

#### **`get_ce_rmue(onspilltime, nsig, run_mode = '1BB')`**

A utility to work backward: calculates the **Reconstructed Muon to Electron Conversion Efficiency (RMUE)** given an observed number of signal events ($N_{\text{sig}}$) and the run time.

$$
\text{RMUE} = \frac{N_{\text{sig}}}{\text{Total POT} \times \frac{\mu_{\text{stopped}}}{\text{POT}} \times \frac{\mu_{\text{captured}}}{\mu_{\text{stopped}}}}
$$

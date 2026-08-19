#!/usr/bin/env python3
"""
Test RMC spectrum fractions computation using correct K_max values.
"""

import math

RMC_KMAX_0N = 101.8667  # MeV, 0-nucleon knockout endpoint on Al-27
RMC_KMAX_1N = 95.4489   # MeV, 1-nucleon knockout endpoint on Al-27

def plestid_integral(K_1, K_2, KMax, knockout):
    """Calculates the integral of the Plestid phase-space approximation spectrum."""
    if KMax <= 0.0:
        return 0.0
    if knockout < 0:
        return 0.0
    
    K_1 = max(0.0, min(KMax, K_1))
    K_2 = max(0.0, min(KMax, K_2))
    
    if K_1 >= K_2:
        return 0.0
    
    power = 2.0 + 1.5 * knockout
    x_1 = K_1 / KMax
    x_2 = K_2 / KMax
    
    val_1 = (x_1 - 1.0) * pow(1.0 - x_1, power) * (power * x_1 + x_1 + 1.0)
    val_2 = (x_2 - 1.0) * pow(1.0 - x_2, power) * (power * x_2 + x_2 + 1.0)
    
    integral = val_2 - val_1
    return integral

# Compute integrals for each knockout mode using its own K_max
frac_0_0n  = plestid_integral(0.0, RMC_KMAX_0N, RMC_KMAX_0N, 0)
frac_0_1n  = plestid_integral(0.0, RMC_KMAX_1N, RMC_KMAX_1N, 1)
frac_57_0n = plestid_integral(57.0, RMC_KMAX_0N, RMC_KMAX_0N, 0)
frac_57_1n = plestid_integral(57.0, RMC_KMAX_1N, RMC_KMAX_1N, 1)
frac_80_0n = plestid_integral(80.0, RMC_KMAX_0N, RMC_KMAX_0N, 0)
frac_80_1n = plestid_integral(80.0, RMC_KMAX_1N, RMC_KMAX_1N, 1)

# Compute ratios: integral above threshold / integral from 0 to K_max
RMC_SPECTRUM_FRAC_0N_57 = frac_57_0n / frac_0_0n if frac_0_0n != 0 else 0.0
RMC_SPECTRUM_FRAC_1N_57 = frac_57_1n / frac_0_1n if frac_0_1n != 0 else 0.0
RMC_SPECTRUM_FRAC_0N_80 = frac_80_0n / frac_0_0n if frac_0_0n != 0 else 0.0
RMC_SPECTRUM_FRAC_1N_80 = frac_80_1n / frac_0_1n if frac_0_1n != 0 else 0.0

# Expected values from the hardcoded constants
expected = {
    'RMC_SPECTRUM_FRAC_0N_57': 0.22887,
    'RMC_SPECTRUM_FRAC_1N_57': 0.061620,
    'RMC_SPECTRUM_FRAC_0N_80': 0.03319,
    'RMC_SPECTRUM_FRAC_1N_80': 0.0013175
}

print("=" * 80)
print("RMC Spectrum Fractions: Computed vs. Expected")
print("=" * 80)
print(f"{'Constant':<25} {'Computed':<15} {'Expected':<15} {'Difference':<15}")
print("-" * 80)

computed_values = {
    'RMC_SPECTRUM_FRAC_0N_57': RMC_SPECTRUM_FRAC_0N_57,
    'RMC_SPECTRUM_FRAC_1N_57': RMC_SPECTRUM_FRAC_1N_57,
    'RMC_SPECTRUM_FRAC_0N_80': RMC_SPECTRUM_FRAC_0N_80,
    'RMC_SPECTRUM_FRAC_1N_80': RMC_SPECTRUM_FRAC_1N_80
}

for key in computed_values:
    comp = computed_values[key]
    exp = expected[key]
    diff = abs(comp - exp)
    rel_diff = diff / exp * 100 if exp != 0 else 0
    print(f"{key:<25} {comp:<15.8f} {exp:<15.8f} {diff:.2e} ({rel_diff:.2f}%)")

print("=" * 80)

#! /usr/bin/env
"""
Physical constants and interaction rates used in Mu2e simulations.
References for these values can be found in the referenced documentation.
"""

# --- Muon Interactions ---
# Fraction of stopped muons that undergo nuclear capture
CAPTURES_PER_STOPPED_MUON = 0.609
# Rate of radiative muon capture (RMC) events resulting in a gamma ray > 57 MeV, per capture event
RMC_GT_57_PER_CAPTURE  = 1.43e-5 # Source: Phys. Rev. C 59, 2853 (1999)
# Fraction of stopped muons that undergo standard DIO (Decay In Orbit)
DIO_PER_STOPPED_MUON = 0.391 # Calculated as: 1 - CAPTURES_PER_STOPPED_MUON
# Rate of Incoming Particle Decay After Stopping (IPA)
IPA_DECAYS_PER_STOPPED_MUON  = 0.92990

# --- Pion Interactions ---
# Fraction of stopped pions that result in a Radiative Pion Capture (RPC)
RPC_PER_STOPPED_PION = 0.0215 # Source: Reference uploaded on DocDB-469
# --- Internal Conversion Ratios ---
# Ratio of internal conversion events per RMC event (assuming RPC value is applicable)
INTERNAL_PER_RMC = 0.00690
# Ratio of internal conversion events per RPC event
INTERNAL_RPC_PER_RPC = 0.00690 # Source: Reference uploaded on DocDB-717


# --- Mu2e Constants ---
SPILL=1.695e-6 # seconds per spill
ONEBB_DF = 0.323 # onspill fraction for one-bunch mode
TWOBB_DF = 0.246 # onspill fraction for two-bunch mode
ONEBB_PROTONS_PER_SPILL=1.58e7 # protons per 1695 ns spill in one-bunch mode
TWOBB_PROTONS_PER_SPILL=3.93e7  # protons per 1695 ns spill in two-bunch mode
ONEBB_POT_PER_CYCLE=4e12 # protons per 1.33 s cycle in one-bunch mode
TWOBB_POT_PER_CYCLE=8e12 # protons per 1.4 s cycle in two-bunch mode
ONEBB_CYCLE = 1.33 # seconds per cycle in one-bunch mode
TWOBB_CYCLE = 1.4 # seconds per cycle in two-bunch mode

# --- RMC (Radiative Muon Capture) Physics Constants ---
# Branching ratio for muon capture on nucleus
RMC_BR_MUON_CAPTURE = 0.609
# RMC rate above 57 MeV, relative to OMC
RMC_RATE_GT_57 = 1.41e-5
# Branching ratio fraction for 0-nucleon knockout above 57 MeV
RMC_BR_0N_FRAC_GT_57 = 0.099  # BR(0 knockout | E > 57) / BR(RMC | E > 57)
# Branching ratio fraction for 1-nucleon knockout above 57 MeV
RMC_BR_1N_FRAC_GT_57 = 0.901  # BR(1 knockout | E > 57) / BR(RMC | E > 57)

# RMC K_max values: Energy endpoints for each knockout mode on Al-27
RMC_KMAX_0N = 101.8667  # MeV, 0-nucleon knockout endpoint on Al-27
RMC_KMAX_1N = 95.4489   # MeV, 1-nucleon knockout endpoint on Al-27

# RMC Spectrum Fractions - from experimental/theoretical physics literature
# These represent: R(* knockout | E > threshold) / R(* knockout) 
# i.e., the fraction of the full spectrum above the given energy threshold
RMC_SPECTRUM_FRAC_0N_57 = 0.22887  # Fraction of 0-knockout spectrum above 57 MeV
RMC_SPECTRUM_FRAC_1N_57 = 0.061620  # Fraction of 1-knockout spectrum above 57 MeV
RMC_SPECTRUM_FRAC_0N_80 = 0.03319  # Fraction of 0-knockout spectrum above 80 MeV
RMC_SPECTRUM_FRAC_1N_80 = 0.0013175  # Fraction of 1-knockout spectrum above 80 MeV

# Internal/external conversion ratio for RMC
# rho = BR(internal) / BR(external)
RMC_INTERNAL_EXTERNAL_RATIO = 0.0069  # rho = BR(internal) / BR(external)

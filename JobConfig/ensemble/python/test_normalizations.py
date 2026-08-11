#!/usr/bin/env python
"""
Unit tests for the normalization script.

Tests yield calculations for various physics processes at different POT values.
"""

import unittest
import sys
import os
import numpy as np

# Import normalizations which will call DbService for real database values
import normalizations


class TestNormalizations(unittest.TestCase):
    """Test suite for process yield normalizations."""

    @classmethod
    def setUpClass(cls):
        """Set up test fixtures - calculate reference POT values."""
        # Set environment variable for spectrum files
        if 'MUSE_WORK_DIR' not in os.environ:
            os.environ['MUSE_WORK_DIR'] = '/exp/mu2e/app/users/sophie/newOffline'

        # Test livetimes from MDS3 (cosmic livetime)
        cls.on_spill_time_1BB = 4.4e6 * (88/496) # seconds
        cls.on_spill_time_2BB = 4.4e6 * (88/496)  # seconds
        
        cls.tst_1BB_cycle = normalizations.get_pot(cls.on_spill_time_1BB, run_mode='1BB',printout=False,method='cycle')
        cls.tst_2BB_cycle = normalizations.get_pot(cls.on_spill_time_2BB, run_mode='2BB',printout=False,method='cycle')
        
        print(f"\n{'='*70}")
        print(f"Test POT Values using Cycle Information:")
        print(f"  1BB Mode: {cls.tst_1BB_cycle:.2e} POT")
        print(f"  2BB Mode: {cls.tst_2BB_cycle:.2e} POT")
        print(f"  Database Values (from DbService):")
        print(f"    target_stopped_muons_per_pot: {normalizations.target_stopped_muons_per_pot}")
        print(f"    target_stopped_pions_per_pot: {normalizations.target_stopped_pions_per_pot}")
        print(f"    ipa_stopped_mu_per_POT: {normalizations.ipa_stopped_mu_per_POT}")
        print(f" MOT stopped muons: {normalizations.target_stopped_muons_per_pot*cls.tst_1BB_cycle:.3e} (1BB), {normalizations.target_stopped_muons_per_pot*cls.tst_2BB_cycle:.3e} (2BB)")
        print(f" Captured muons: {normalizations.target_stopped_muons_per_pot*cls.tst_1BB_cycle*normalizations.CAPTURES_PER_STOPPED_MUON:.3e}  (1BB), {normalizations.target_stopped_muons_per_pot*cls.tst_2BB_cycle*normalizations.CAPTURES_PER_STOPPED_MUON:.3e} (2BB)")
        print(f"{'='*70}\n")

        cls.tst_1BB_spill = normalizations.get_pot(cls.on_spill_time_1BB, run_mode='1BB',printout=False,method='spill')
        cls.tst_2BB_spill = normalizations.get_pot(cls.on_spill_time_2BB, run_mode='2BB',printout=False,method='spill')
        
        print(f"\n{'='*70}")
        print(f"Test POT Values using Spill Information:")
        print(f"  1BB Mode: {cls.tst_1BB_spill:.2e} POT")
        print(f"  2BB Mode: {cls.tst_2BB_spill:.2e} POT")
        print(f"  Database Values (from DbService):")
        print(f"    target_stopped_muons_per_pot: {normalizations.target_stopped_muons_per_pot}")
        print(f"    target_stopped_pions_per_pot: {normalizations.target_stopped_pions_per_pot}")
        print(f"    ipa_stopped_mu_per_POT: {normalizations.ipa_stopped_mu_per_POT}")
        print(f" MOT stopped muons: {normalizations.target_stopped_muons_per_pot*cls.tst_1BB_spill:.3e} (1BB), {normalizations.target_stopped_muons_per_pot*cls.tst_2BB_spill:.3e} (2BB)")
        print(f" Captured muons: {normalizations.target_stopped_muons_per_pot*cls.tst_1BB_spill*normalizations.CAPTURES_PER_STOPPED_MUON:.3e}  (1BB), {normalizations.target_stopped_muons_per_pot*cls.tst_2BB_spill*normalizations.CAPTURES_PER_STOPPED_MUON:.3e} (2BB)")
        print(f"{'='*70}\n")

        

    def test_pot_calculations(self):
        """Verify POT calculations match expected values."""
        # Get POT for known inputs
        pot_1bb_cycle = normalizations.get_pot(self.on_spill_time_1BB, run_mode='1BB', printout=False,method='cycle')
        pot_2bb_cycle = normalizations.get_pot(self.on_spill_time_2BB, run_mode='2BB', printout=False,method='cycle')
        
        # POT should be positive
        self.assertGreater(pot_1bb_cycle, 0)
        self.assertGreater(pot_2bb_cycle, 0)
        
        # 2BB should give more POT for same time (higher protons per cycle)
        self.assertGreater(pot_2bb_cycle, pot_1bb_cycle)

        # Get POT for known inputs
        pot_1bb_spill = normalizations.get_pot(self.on_spill_time_1BB, run_mode='1BB', printout=False,method='spill')
        pot_2bb_spill = normalizations.get_pot(self.on_spill_time_2BB, run_mode='2BB', printout=False,method='spill')
        
        # POT should be positive
        self.assertGreater(pot_1bb_spill, 0)
        self.assertGreater(pot_2bb_spill, 0)
        
        # 2BB should give more POT for same time (higher protons per cycle)
        self.assertGreater(pot_2bb_spill, pot_1bb_spill)

        print(f"\nPOT Comparison:")
        self.assertAlmostEqual(pot_1bb_cycle, pot_1bb_spill, delta=pot_1bb_cycle*0.05)  # Allow 5% difference
        self.assertAlmostEqual(pot_2bb_cycle, pot_2bb_spill, delta=pot_2bb_cycle*0.05)  # Allow 5% difference

    def test_ce_normalization_yields(self):
        """Calculate CE yields for both 1BB and 2BB POT values."""
        # Use reasonable efficiency values
        rue_test = 1e-13  # Typical CE reconstruction efficiency
        
        ce_yield_1bb = normalizations.ce_normalization(
            self.on_spill_time_1BB, rue_test, run_mode='1BB'
        )
        ce_yield_2bb = normalizations.ce_normalization(
            self.on_spill_time_2BB, rue_test, run_mode='2BB'
        )
        
        print(f"CE Yields:")
        print(f"  1BB: {ce_yield_1bb:.2e}")
        print(f"  2BB: {ce_yield_2bb:.2e}")
        
        # Yields should be non-negative
        self.assertGreaterEqual(ce_yield_1bb, 0)
        self.assertGreaterEqual(ce_yield_2bb, 0)

    def test_dio_normalization_yields(self):
        """Calculate DIO yields for both 1BB and 2BB POT values."""
        # Use a typical energy threshold above the CE signal region
        e_min = 95.0  # MeV, well above CE endpoint at 104.973 MeV
        
        dio_yield_1bb = normalizations.dio_normalization(
            self.on_spill_time_1BB, e_min, run_mode='1BB'
        )
        dio_yield_2bb = normalizations.dio_normalization(
            self.on_spill_time_2BB, e_min, run_mode='2BB'
        )
        
        print(f"\nDIO Yields (above {e_min} MeV):")
        print(f"  1BB: {dio_yield_1bb:.2e}")
        print(f"  2BB: {dio_yield_2bb:.2e}")
        
        self.assertGreater(dio_yield_1bb, 0)
        self.assertGreater(dio_yield_2bb, 0)

    def test_rpc_external_yields(self):
        """Calculate RPC (external) yields for both 1BB and 2BB POT values."""
        e_min = 50.0  # MeV
        t_min = 350.0  # ns
        
        rpc_yield_1bb = normalizations.rpc_normalization(
            self.on_spill_time_1BB, t_min, internal=0, e_min=e_min, run_mode='1BB'
        )
        rpc_yield_2bb = normalizations.rpc_normalization(
            self.on_spill_time_2BB, t_min, internal=0, e_min=e_min, run_mode='2BB'
        )
        
        print(f"\nRPC External Yields (above {e_min} MeV, {t_min} ns):")
        print(f"  1BB: {rpc_yield_1bb:.2e}")
        print(f"  2BB: {rpc_yield_2bb:.2e}")
        
        self.assertGreater(rpc_yield_1bb, 0)
        self.assertGreater(rpc_yield_2bb, 0)

    def test_rpc_internal_yields(self):
        """Calculate RPC (internal conversion) yields for both 1BB and 2BB POT values."""
        e_min = 50.0  # MeV
        t_min = 350.0  # ns
        
        rpc_yield_1bb = normalizations.rpc_normalization(
            self.on_spill_time_1BB, t_min, internal=1, e_min=e_min, run_mode='1BB'
        )
        rpc_yield_2bb = normalizations.rpc_normalization(
            self.on_spill_time_2BB, t_min, internal=1, e_min=e_min, run_mode='2BB'
        )
        
        print(f"\nRPC Internal Yields (above {e_min} MeV, {t_min} ns):")
        print(f"  1BB: {rpc_yield_1bb:.2e}")
        print(f"  2BB: {rpc_yield_2bb:.2e}")
        
        self.assertGreater(rpc_yield_1bb, 0)
        self.assertGreater(rpc_yield_2bb, 0)

    def test_rmc_external_yields(self):
        """Calculate RMC (external) yields for both 1BB and 2BB POT values."""
        e_min = 85  # MeV (RMC threshold)
        
        rmc_yield_1bb = normalizations.rmc_normalization(
            self.on_spill_time_1BB, internal=0, e_min=e_min, run_mode='1BB'
        )
        rmc_yield_2bb = normalizations.rmc_normalization(
            self.on_spill_time_2BB, internal=0, e_min=e_min, run_mode='2BB'
        )
        
        print(f"\nRMC External Yields (above {e_min} MeV):")
        print(f"  1BB: {rmc_yield_1bb:.2e}")
        print(f"  2BB: {rmc_yield_2bb:.2e}")
        
        self.assertGreater(rmc_yield_1bb, 0)
        self.assertGreater(rmc_yield_2bb, 0)

    def test_rmc_internal_yields(self):
        """Calculate RMC (internal conversion) yields for both 1BB and 2BB POT values."""
        e_min = 85  # MeV (RMC threshold)
        
        rmc_yield_1bb = normalizations.rmc_normalization(
            self.on_spill_time_1BB, internal=1, e_min=e_min, run_mode='1BB'
        )
        rmc_yield_2bb = normalizations.rmc_normalization(
            self.on_spill_time_2BB, internal=1, e_min=e_min, run_mode='2BB'
        )
        
        print(f"\nRMC Internal Yields (above {e_min} MeV):")
        print(f"  1BB: {rmc_yield_1bb:.2e}")
        print(f"  2BB: {rmc_yield_2bb:.2e}")
        
        self.assertGreater(rmc_yield_1bb, 0)
        self.assertGreater(rmc_yield_2bb, 0)

    def test_rmc_0n_external_yields(self):
        """Calculate RMC 0-nucleon knockout (external) yields for both 1BB and 2BB POT values."""
        e_min = 80  # MeV
        
        rmc_0n_yield_1bb = normalizations.rmc_0n_normalization(
            self.on_spill_time_1BB, e_min, internal=0, run_mode='1BB'
        )
        rmc_0n_yield_2bb = normalizations.rmc_0n_normalization(
            self.on_spill_time_2BB, e_min, internal=0, run_mode='2BB'
        )
        
        print(f"\nRMC 0N External Yields (above {e_min} MeV):")
        print(f"  1BB: {rmc_0n_yield_1bb:.2e}")
        print(f"  2BB: {rmc_0n_yield_2bb:.2e}")
        
        self.assertGreater(rmc_0n_yield_1bb, 0)
        self.assertGreater(rmc_0n_yield_2bb, 0)

    def test_rmc_0n_internal_yields(self):
        """Calculate RMC 0-nucleon knockout (internal conversion) yields for both 1BB and 2BB POT values."""
        e_min = 80  # MeV
        
        rmc_0n_yield_1bb = normalizations.rmc_0n_normalization(
            self.on_spill_time_1BB, e_min, internal=1, run_mode='1BB'
        )
        rmc_0n_yield_2bb = normalizations.rmc_0n_normalization(
            self.on_spill_time_2BB, e_min, internal=1, run_mode='2BB'
        )
        
        print(f"\nRMC 0N Internal Yields (above {e_min} MeV):")
        print(f"  1BB: {rmc_0n_yield_1bb:.2e}")
        print(f"  2BB: {rmc_0n_yield_2bb:.2e}")
        
        self.assertGreater(rmc_0n_yield_1bb, 0)
        self.assertGreater(rmc_0n_yield_2bb, 0)

    def test_rmc_1n_external_yields(self):
        """Calculate RMC 1-nucleon knockout (external) yields for both 1BB and 2BB POT values."""
        e_min = 80  # MeV
        
        rmc_1n_yield_1bb = normalizations.rmc_1n_normalization(
            self.on_spill_time_1BB, e_min, internal=0, run_mode='1BB'
        )
        rmc_1n_yield_2bb = normalizations.rmc_1n_normalization(
            self.on_spill_time_2BB, e_min, internal=0, run_mode='2BB'
        )
        
        print(f"\nRMC 1N External Yields (above {e_min} MeV):")
        print(f"  1BB: {rmc_1n_yield_1bb:.2e}")
        print(f"  2BB: {rmc_1n_yield_2bb:.2e}")
        
        self.assertGreater(rmc_1n_yield_1bb, 0)
        self.assertGreater(rmc_1n_yield_2bb, 0)

    def test_rmc_1n_internal_yields(self):
        """Calculate RMC 1-nucleon knockout (internal conversion) yields for both 1BB and 2BB POT values."""
        e_min = 80  # MeV
        
        rmc_1n_yield_1bb = normalizations.rmc_1n_normalization(
            self.on_spill_time_1BB, e_min, internal=1, run_mode='1BB'
        )
        rmc_1n_yield_2bb = normalizations.rmc_1n_normalization(
            self.on_spill_time_2BB, e_min, internal=1, run_mode='2BB'
        )
        
        print(f"\nRMC 1N Internal Yields (above {e_min} MeV):")
        print(f"  1BB: {rmc_1n_yield_1bb:.2e}")
        print(f"  2BB: {rmc_1n_yield_2bb:.2e}")
        
        self.assertGreater(rmc_1n_yield_1bb, 0)
        self.assertGreater(rmc_1n_yield_2bb, 0)

    def test_ipa_michel_normalization_yields(self):
        """Calculate IPA Michel yields for both 1BB and 2BB POT values."""
        ipa_de_min = 50.0  # MeV
        
        ipa_yield_1bb = normalizations.ipaMichel_normalization(
            self.on_spill_time_1BB, ipa_de_min, run_mode='1BB'
        )
        ipa_yield_2bb = normalizations.ipaMichel_normalization(
            self.on_spill_time_2BB, ipa_de_min, run_mode='2BB'
        )
        
        print(f"\nIPA Michel Yields (above {ipa_de_min} MeV):")
        print(f"  1BB: {ipa_yield_1bb:.2e}")
        print(f"  2BB: {ipa_yield_2bb:.2e}")
        
        self.assertGreater(ipa_yield_1bb, 0)
        self.assertGreater(ipa_yield_2bb, 0)

    def test_all_yields_summary(self):
        """Generate a summary of all yields for reference POT values."""
        print(f"\n{'='*70}")
        print(f"NORMALIZATION YIELDS SUMMARY")
        print(f"{'='*70}")
        
        # 1BB mode
        print(f"\n1BB Mode (POT: {self.tst_1BB_spill:.3e}):")
        print(f"  Livetime: {self.on_spill_time_1BB:.3e} seconds")
        print(f"  Duty Factor: {normalizations.get_duty_factor('1BB')}")
        
        ce_1bb = normalizations.ce_normalization(self.on_spill_time_1BB, 1e-13, run_mode='1BB')
        dio_1bb = normalizations.dio_normalization(self.on_spill_time_1BB, 95.0, run_mode='1BB')
        rpc_ext_1bb = normalizations.rpc_normalization(self.on_spill_time_1BB, 350, 0, 50.0, run_mode='1BB')
        rpc_int_1bb = normalizations.rpc_normalization(self.on_spill_time_1BB, 350, 1, 50.0, run_mode='1BB')
        rmc_ext_1bb = normalizations.rmc_normalization(self.on_spill_time_1BB, 0, 85, run_mode='1BB')
        rmc_int_1bb = normalizations.rmc_normalization(self.on_spill_time_1BB, 1, 85, run_mode='1BB')
        rmc_0n_ext_1bb = normalizations.rmc_0n_normalization(self.on_spill_time_1BB, 80, internal=0, run_mode='1BB')
        rmc_0n_int_1bb = normalizations.rmc_0n_normalization(self.on_spill_time_1BB, 80, internal=1, run_mode='1BB')
        rmc_1n_ext_1bb = normalizations.rmc_1n_normalization(self.on_spill_time_1BB, 80, internal=0, run_mode='1BB')
        rmc_1n_int_1bb = normalizations.rmc_1n_normalization(self.on_spill_time_1BB, 80, internal=1, run_mode='1BB')
        ipa_1bb = normalizations.ipaMichel_normalization(self.on_spill_time_1BB, 50.0, run_mode='1BB')
        
        print(f"\n  Process Yields:")
        print(f"    CE (RUE=1e-13):                  {ce_1bb:.3e}")
        print(f"    DIO (E>95 MeV):                  {dio_1bb:.3e}")
        print(f"    RPC External (E>50 MeV):        {rpc_ext_1bb:.3e}")
        print(f"    RPC Internal (E>50 MeV):        {rpc_int_1bb:.3e}")
        print(f"    RMC External (E>85 MeV):        {rmc_ext_1bb:.3e}")
        print(f"    RMC Internal (E>85 MeV):        {rmc_int_1bb:.3e}")
        print(f"    RMC 0N External (E>80 MeV):     {rmc_0n_ext_1bb:.3e}")
        print(f"    RMC 0N Internal (E>80 MeV):     {rmc_0n_int_1bb:.3e}")
        print(f"    RMC 1N External (E>80 MeV):     {rmc_1n_ext_1bb:.3e}")
        print(f"    RMC 1N Internal (E>80 MeV):     {rmc_1n_int_1bb:.3e}")
        print(f"    IPA Michel (E>50 MeV):          {ipa_1bb:.3e}")
        
        # 2BB mode
        print(f"\n2BB Mode (POT: {self.tst_2BB_spill:.3e}):")
        print(f"  Livetime: {self.on_spill_time_2BB:.3e} seconds")
        print(f"  Duty Factor: {normalizations.get_duty_factor('2BB')}")
        
        ce_2bb = normalizations.ce_normalization(self.on_spill_time_2BB, 1e-13, run_mode='2BB')
        dio_2bb = normalizations.dio_normalization(self.on_spill_time_2BB, 95.0, run_mode='2BB')
        rpc_ext_2bb = normalizations.rpc_normalization(self.on_spill_time_2BB, 350, 0, 50.0, run_mode='2BB')
        rpc_int_2bb = normalizations.rpc_normalization(self.on_spill_time_2BB, 350, 1, 50.0, run_mode='2BB')
        rmc_ext_2bb = normalizations.rmc_normalization(self.on_spill_time_2BB, 0, 85, run_mode='2BB')
        rmc_int_2bb = normalizations.rmc_normalization(self.on_spill_time_2BB, 1, 85, run_mode='2BB')
        rmc_0n_ext_2bb = normalizations.rmc_0n_normalization(self.on_spill_time_2BB, 80, internal=0, run_mode='2BB')
        rmc_0n_int_2bb = normalizations.rmc_0n_normalization(self.on_spill_time_2BB, 80, internal=1, run_mode='2BB')
        rmc_1n_ext_2bb = normalizations.rmc_1n_normalization(self.on_spill_time_2BB, 80, internal=0, run_mode='2BB')
        rmc_1n_int_2bb = normalizations.rmc_1n_normalization(self.on_spill_time_2BB, 80, internal=1, run_mode='2BB')
        ipa_2bb = normalizations.ipaMichel_normalization(self.on_spill_time_2BB, 50.0, run_mode='2BB')
        
        print(f"\n  Process Yields:")
        print(f"    CE (RUE=1e-13):                  {ce_2bb:.3e}")
        print(f"    DIO (E>95 MeV):                  {dio_2bb:.3e}")
        print(f"    RPC External (E>50 MeV):        {rpc_ext_2bb:.3e}")
        print(f"    RPC Internal (E>50 MeV):        {rpc_int_2bb:.3e}")
        print(f"    RMC External (E>85 MeV):        {rmc_ext_2bb:.3e}")
        print(f"    RMC Internal (E>85 MeV):        {rmc_int_2bb:.3e}")
        print(f"    RMC 0N External (E>80 MeV):     {rmc_0n_ext_2bb:.3e}")
        print(f"    RMC 0N Internal (E>80 MeV):     {rmc_0n_int_2bb:.3e}")
        print(f"    RMC 1N External (E>80 MeV):     {rmc_1n_ext_2bb:.3e}")
        print(f"    RMC 1N Internal (E>80 MeV):     {rmc_1n_int_2bb:.3e}")
        print(f"    IPA Michel (E>50 MeV):          {ipa_2bb:.3e}")
        
        print(f"\n{'='*70}\n")


if __name__ == '__main__':
    unittest.main(verbosity=2)

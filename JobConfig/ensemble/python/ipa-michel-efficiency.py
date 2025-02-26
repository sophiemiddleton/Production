#! /usr/bin/env python
# Ed Callaghan
# Gross generator efficiency --- includes threshold, and atomic/nuclear capture
# November 2024

from matplotlib import pyplot as plt
import numpy as np
import os
import scipy.interpolate as si
from scipy.integrate import quad

def load_spectrum(path):
    arr = np.loadtxt(path)
    xx = arr[:,0]
    yy = arr[:,1]
    print(xx,yy)
    return xx, yy

def calculate_weights(d):
    normalization = 0.0
    for k,v in d.items():
        volume = pow(v['atomic_radius'], 3.0)
        volume *= v['mass_fraction'] / v['atomic_mass']
        v['volume_fraction'] = volume
        normalization += volume
    for v in d.values():
        v['volume_fraction'] /= normalization

    normalization = 0.0
    for k,v in d.items():
        weight = v['volume_fraction'] * v['decay_fraction']
        v['weight'] = weight
        normalization += weight
    for v in d.values():
        v['weight'] /= normalization


def generate_interpolations(d):
    for k,v in d.items():
        v['interpolation'] = si.interp1d(*v['spectrum'],
                                         bounds_error=False,
                                         fill_value=0.0)

elements = {
    'C': {
          'mass_fraction': 0.89,    # fractional
          'decay_fraction': 0.922,  # fractional
          'atomic_mass': 12.0107,   # atomic mass units
          'atomic_radius': 75.0,    # picometers
          'spectrum': load_spectrum("heeck_finer_binning_2016_szafron-scaled-to-6C.tbl"),
         },
    'H': {
          'decay_fraction': 0.999,  # fractional
          'mass_fraction': 0.11,    # fractional
          'atomic_mass': 1.007975,  # atomic mass units
          'atomic_radius': 32.0,    # picometers
          'spectrum': load_spectrum("heeck_finer_binning_2016_szafron-scaled-to-1H.tbl"),
         },
}
calculate_weights(elements)
generate_interpolations(elements)

decay_efficiency = sum([v['volume_fraction'] * v['decay_fraction'] \
                        for v in elements.values()])
for k,v in elements.items():
    tup = (k, v['volume_fraction'], v['decay_fraction'], v['weight'])
    print('%s: %.3f %.3f %.3f' % tup)
print('decay efficiency: %.3f%%' % (100.0 * decay_efficiency))

xmin = min([v['spectrum'][0][0]  for v in elements.values()])
xmax = max([v['spectrum'][0][-1] for v in elements.values()])
xx = np.linspace(xmin, xmax, int(1e6))
yy = sum([v['weight'] * v['interpolation'](xx) for v in elements.values()])
yy /= np.trapz(yy, xx)
spectrum = si.interp1d(xx, yy)
integral = quad(spectrum, xmin, xmax)
print(integral)

fig = plt.figure()
plt.xlabel('Energy [MeV]')
plt.ylabel(r'Probability density [MeV$^{-1}$]')
plt.plot(xx, yy)
plt.tight_layout()
plt.savefig('composite-spectrum.pdf')

xx = np.linspace(50.0, 100.0, int(100))
yy = np.array([quad(spectrum, x, xmax) for x in xx])
spectral_efficiency = yy[:,0]
yy = spectral_efficiency

fig = plt.figure()
plt.yscale('log')
plt.xlabel('Threshold [MeV]')
plt.ylabel('Spectral efficiency [%]')
plt.plot(xx, 100.0 * yy)
for i,j in enumerate(xx):
  print(xx[i], yy[i])
plt.tight_layout()
plt.savefig('spectral-efficiency-vs-threshold.pdf')

# 2 hours per 10^{4} decays
scaling = 2.0 * 1.0e-4

# total runtime cost
stops = 2e9
decays = stops * decay_efficiency * spectral_efficiency
cost = scaling * decays
yy = cost

fig = plt.figure()
plt.yscale('log')
plt.xlabel('Threshold [MeV]')
plt.ylabel('Runtime [CPU-hours]')
plt.plot(xx, yy)
plt.tight_layout()
plt.savefig('ost-vs-threshold.pdf')

plt.show()


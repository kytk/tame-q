#!/usr/bin/env python3
# -*- coding: utf-8 -*-

### TAME-Q reference_policy.py
# 8 Mar 2026 K.Nakayama and K.Nemoto

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

import os, sys
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
import argparse
import textwrap

__version__ = 'version 20260315'

def calc_fwhm(mu, sigma):
    fwhm_min=mu-sigma*pow(2*np.log(2), 1/2)
    fwhm_max=mu+sigma*pow(2*np.log(2), 1/2)
    return fwhm_min, fwhm_max

def gaussian(x, a, b, c):
    return a*np.exp(-pow((x-b)/c, 2)/2)/pow(2*np.pi, 1/2)/c

def determine_reference_voxel(pet, params, histogramfile=None):
    if histogramfile!=None:
        histogram=np.load(histogramfile)
        
    mono_a1, mono_b1, mono_c1=params['monomodal']['a1'], params['monomodal']['b1'], params['monomodal']['c1']
    bi_a1, bi_b1, bi_c1=params['bimodal']['a1'], params['bimodal']['b1'], params['bimodal']['c1']
    bi_a2, bi_b2, bi_c2=params['bimodal']['a2'], params['bimodal']['b2'], params['bimodal']['c2']
    
    height1=bi_a1/bi_c1/pow(2*np.pi, 1/2)
    height2=bi_a2/bi_c2/pow(2*np.pi, 1/2)
    if height1<height2/2 and params['monomodal']['dice']>0.936:
        fwhm_min, fwhm_max=calc_fwhm(mono_b1, mono_c1)
        out=np.where((fwhm_min<pet)&(pet<fwhm_max), 1, 0)
    else:
        fwhm_min, fwhm_max=calc_fwhm(bi_b1, bi_c1)
        weight1=gaussian(pet, bi_a1, bi_b1, bi_c1)
        weight2=gaussian(pet, bi_a2, bi_b2, bi_c2)
        sum_weight=weight1+weight2
        sum_weight[sum_weight==0]=1e-10
        out=np.where((fwhm_min<pet)&(pet<fwhm_max), weight1/sum_weight, 0)

    return out

def determine_parameter(N_curve, bin_centers, bin_counts):
    if N_curve==1:
        initparam=[np.max(bin_counts), bin_centers[np.argmax(bin_counts)], 0.5]
        param_bounds=[[0, bin_centers[0], 0], [np.inf, bin_centers[-1], np.inf]]
    else:
        initparam=[]
        tmpbins=np.linspace(bin_centers[0], bin_centers[-1], N_curve+2)
        for i in range(1, N_curve+1):
            initparam=initparam+[np.max(bin_counts)/N_curve, tmpbins[i], 1]
        param_bounds=[[0]*(3*N_curve), [1.5*np.max(bin_counts), bin_centers[-1], np.inf]*N_curve]
    return initparam, param_bounds

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted", file=sys.stderr)
        sys.exit(130)
    except ValueError as e:
        print(f"Value Error: {e}", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(e, file=sys.stderr)
        raise SystemExit(1)  # 失敗

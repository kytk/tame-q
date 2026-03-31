#!/usr/bin/env python3
# -*- coding: utf-8 -*-

### TAME-Q nifti_wmean.py
# 27 Mar 2026 K.Nakayama and K.Nemoto

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

import os, sys
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit
import argparse
import textwrap
from importlib.util import spec_from_file_location, module_from_spec

__version__ = 'version 20260327'

__desc__ = '''
(The description will be prepared in future release.)
'''
__epilog__ = '''
(The description will be prepared in future release.)
'''

def load_nifti(nifti, nan_to_zero=True):
    img=nib.load(nifti)
    if nan_to_zero==True:
        mat=np.nan_to_num(img.get_fdata())
    else:
        mat=img.get_fdata()
    return mat, img.header, img.affine

class InconsistentSpaceError(Exception):
    def __init__(self, message):
        super().__init__(message)

def check_matrix_compatibility(mat1, mat2):
    if mat1.shape[0]!=mat2.shape[0] or mat1.shape[1]!=mat2.shape[1] or mat1.shape[2]!=mat2.shape[2]:
        return False
    return True

def check_header_compatibility(header1, header2):
    #pix
    dim1=[1 if x==0 else x for x in header1['dim'] ]
    dim2=[1 if x==0 else x for x in header2['dim'] ]
    for d1, d2 in zip(dim1, dim2):
        if d1 != d2:
            return False
            
    #pixdim
    pixdim1=[1 if x==0 else x for x in header1['pixdim']]
    pixdim2=[1 if x==0 else x for x in header2['pixdim']]
    for p1, p2 in zip(pixdim1, pixdim2):
        if abs(d1-d2)>1e-6:
            return False

    return True

def check_affine_compatibility(affine1, affine2):
    if np.abs(affine1-affine2).max()>1e-6:
        return False
    
    return True

def main():
    # Read command line argument
    f_image = sys.argv[1]
    f_weight = sys.argv[2]

    # Load images
    in_mat, in_header, in_affine=load_nifti(f_image)
    weight_mat, weight_header, weight_affine=load_nifti(f_weight)
    if check_matrix_compatibility(in_mat, weight_mat)==False:
        raise InconsistentSpaceError("Matrix shapes are not compatible.")

    if check_header_compatibility(in_header, weight_header)==False:
        raise InconsistentSpaceError("Dimensions are not compatible.")

    if check_affine_compatibility(in_affine, weight_affine)==False:
        raise InconsistentSpaceError("Affine matrixs are not compatible.")

    # Calculate weighted mean
    wmean = np.sum(in_mat * weight_mat)/np.sum(weight_mat)

    print(wmean)
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted", file=sys.stderr)
        sys.exit(130)
    except ValueError as e:
        print(f"Value Error: {e}", file=sys.stderr)
        sys.exit(130)
    except InconsistentSpaceError as e:
        print(f"Inconsistent Space Error: {e}", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(e, file=sys.stderr)
        raise SystemExit(1)  # 失敗

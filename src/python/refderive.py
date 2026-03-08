#!/usr/bin/env python3
# -*- coding: utf-8 -*-

### TAME-Q curve_det.py
# 8 Mar 2026 K.Nakayama and K.Nemoto

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

__version__ = 'version 20260315'

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

def save_nifti(mat, header=None, affine=None, filename=None):
    out=nib.Nifti1Image(mat, header=header, affine=affine)
    nib.save(out, filename)
    return

def masking(mat, mask):
    mask=np.where(mask>0, 1, 0)
    mat=mat*mask
    return mat

def extract_curve_param(f):
    with open(f, "r") as f:
        text=f.read()

    textlist=text.splitlines()
    paramstext=textlist[(len(textlist)-1-textlist[::-1].index("### Curve fit result")):]

    outdict=dict()
    for t in paramstext:
        if '=' in t:
            ts=t.split('=')
            outdict[ts[0]]=float(ts[1])
    return outdict

def get_curveinfo_list(curvefiles, curvelabels):
    out=dict()
    for f, label in zip(curvefiles, curvelabels):
        paramdict=extract_curve_param(f)
        out[label]=paramdict
    return out

def main():
    # Read command line argument
    parser = argparse.ArgumentParser(
        description=__desc__, epilog=__epilog__, add_help=True, formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument('-v', '--version', action='version', version=f'%(prog)s {__version__}')
    parser.add_argument('--input', type=str, required=True, help='Input image')
    parser.add_argument('--output', type=str, required=True, help='Output image')
    parser.add_argument('--curvefile', nargs='*', default=[], required=True, help='Curve fit result textfile')
    parser.add_argument('--curvelabel', nargs='*', default=[], required=True, help='Curve fit result label')
    parser.add_argument('--mask', type=str, help='Mask image for curve fit')
    parser.add_argument('--policy', type=str, default=os.path.join(os.path.dirname(__file__), "reference_policy.py"), help='Policy file for reference value')
    parser.add_argument('--targethist', default=None, help='Numpy array of target histogram')
    
    args=parser.parse_args()
    
    inputfile=args.input
    outputfile=args.output
    curvefiles=args.curvefile
    curvelabels=args.curvelabel
    maskfile=args.mask
    policyfile=args.policy
    targethist=args.targethist

    in_mat, in_header, in_affine=load_nifti(inputfile)
    if maskfile!=None:
        flag_mask=True
        mask_mat, _, _=load_nifti(maskfile)
    else:
        flag_mask=False

    # Import reference policy function
    sys.dont_write_bytecode=True    # Suppress __pycache__ 
    spec=spec_from_file_location("refpolicy", policyfile)
    module=module_from_spec(spec)
    spec.loader.exec_module(module)

    sys.modules['refpolicy']=module
    from refpolicy import determine_reference_voxel

    ### Input Validation
    # Future release ...

    # Mask if necessary
    if flag_mask==True:
        in_mat=masking(in_mat, mask_mat)
    
    # Create curve info list
    curveinfos=get_curveinfo_list(curvefiles, curvelabels)
    
    # Determine reference
    reference_weight=determine_reference_voxel(in_mat, curveinfos, histogramfile=targethist)
    save_nifti(reference_weight, header=in_header, affine=in_affine, filename=outputfile)
    
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
    except Exception as e:
        print(e, file=sys.stderr)
        raise SystemExit(1)  # 失敗

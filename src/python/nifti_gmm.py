#!/usr/bin/env python3
# -*- coding: utf-8 -*-

### TAME-Q nifti_gmm.py
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

__version__ = 'version 20260228'

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

def within_percentile(nums, thrp, uthrp):    
    lower_threshold=np.percentile(nums, thrp)
    upper_threshold=np.percentile(nums, uthrp)
    nums=nums[~(nums<lower_threshold)]
    nums=nums[~(nums>upper_threshold)]
    return nums

def get_histogram(values, bin_width, bin_n, bin_min, bin_max):
    # Input validation
    if bin_width!=None and bin_n!=None:
        raise ValueError("bin_width and bin_n cannot be set at the same time.")
    
    # Set histogram min/max
    if bin_min==None:
        bin_min=np.min(values)
    if bin_max==None:
        bin_max=np.max(values)
    
    if bin_width==None:
        if bin_n==None:
            bin_n=100    
        bins=np.linspace(bin_min, bin_max, bin_n+1)
    else:
        bins=np.arange(bin_min, bin_max+bin_width, bin_width)
    
    out=np.histogram(values, bins=bins)
    return out

def get_func_gmm_n(n):
    def func_gmm_n(x, *param):
        y=np.zeros(x.shape[0])
        n_curve=len(param)//3
        for i in range(n_curve):
            y+=param[3*i]*np.exp(-pow((x-param[3*i+1])/param[3*i+2], 2)/2)/pow(2*np.pi, 1/2)/param[3*i+2]
        return y
    return func_gmm_n

def reshape_popt(popt):
    # Reshape popt into (n_curve, 3) 
    out=popt.reshape(-1, 3)
    # Sort popt from lower-mean curve
    out=out[np.argsort(out[:, 1])]
    return out
    
def gmm_fit(bin_centers, bin_counts, n=1, params=None, bounds=None):
    if len(params)==0:
        init_a=bin_counts.max()*pow(2*np.pi, 1/2)/n
        for i in range(n):
            params=params+[init_a, bin_centers[(i+1)*len(bin_centers)//(n+1)], 1]

    if len(bounds[0])==0:
        bounds[0]=[-np.inf, -np.inf, -np.inf]*n
    if len(bounds[1])==0:
        bounds[1]=[np.inf, np.inf, np.inf]*n
        
    func_gmm_n=get_func_gmm_n(n)

    popt, pcov=curve_fit(func_gmm_n, bin_centers, bin_counts, p0=params, bounds=bounds)
    popt=reshape_popt(popt)
    return popt

def get_gaussian(a, b, c):
  def gaussian(x):
    return a*np.exp(-pow((x-b)/c, 2)/2)/pow(2*np.pi, 1/2)/c
  return gaussian

def calc_dice(y1, y2):
    return 2*np.sum([np.min([v1, v2]) for v1, v2 in zip(y1, y2)])/(np.sum(y1)+np.sum(y2))

def save_curve_fit_fig(x, y, fitparam, filename, figsize=6, figtype=1):
    N_curve=fitparam.shape[0]

    # Define color
    data_curve_color="#7f7f7f"
    curve_color_cycle=["#1f77b4", "#2ca02c", "#ff7f0e", "#9467bd", "#8c564b", "#e377c2", "#bcbd22", "#17becf"]
    mixture_curve_color="#d62728"

    ### Plot curve
    fig=plt.figure(figsize=(figsize, figsize))
    ax=fig.add_subplot(111)
    
    # Plot original data
    ax.plot(x, y, c=data_curve_color, alpha=0.3, label='original')

    # Plot curve fit result
    mixture=np.zeros(x.shape[0])
    for i in range(N_curve):
        # Plot curve (i+1)
        g=get_gaussian(fitparam[i, 0], fitparam[i, 1], fitparam[i, 2])
        y_i=g(x)
        ax.plot(x, y_i, alpha=0.8, color=curve_color_cycle[i%8], label=f'curve{i+1}')

        # Display parameters (i+1) if necessary
        if figtype>1:
            ax.text(0.6, 0.52-0.2*i, f'  a{i+1}  : {fitparam[i, 0]:.2f}', transform=ax.transAxes)
            ax.text(0.6, 0.46-0.2*i, f' mu{i+1}  : {fitparam[i, 1]:.3f}', transform=ax.transAxes)
            ax.text(0.6, 0.40-0.2*i, f'std{i+1}  : {fitparam[i, 2]:.3f}', transform=ax.transAxes)

        # Store mixtured curve
        mixture=mixture+y_i
    
    # Plot mixture model
    if N_curve>1:
        ax.plot(x, mixture, color=mixture_curve_color, label='mixture')
    
    # Add information on figure
    ax.legend()
    ax.set_xlabel('Value')
    ax.set_ylabel('Frequency')

    # Set figure title
    text_curve='curve' if N_curve==1 else 'curves'
    text_dice=f'(Dice: {calc_dice(y, mixture):.3f})' if figtype>2 else ''
    ax.set_title(f'Curve fit with {N_curve} {text_curve} {text_dice}')
    
    # Save figure
    plt.savefig(filename)
    return

def get_mixture_curve(x, fitparam):
    N_curve=fitparam.shape[0]

    mixture=np.zeros(x.shape[0])
    for i in range(N_curve):
        # Get curve (i+1)
        g=get_gaussian(fitparam[i, 0], fitparam[i, 1], fitparam[i, 2])
        y_i=g(x)
        
        # Store mixtured curve
        mixture=mixture+y_i
    
    return mixture

def coalesce(*args):
    for arg in args:
        if arg is not None:
            return arg
    return None

def get_curve_fit_setting_text(input=None, mask=None, mean=None, thrp=0, uthrp=100, bins=[], params=[], bounds=[None, None]):
    np.set_printoptions(suppress=True, linewidth=np.inf)
    bininfo=f"[{bins[0]}, {bins[1]}, ... , {bins[-2]}, {bins[-1]}]" if len(bins)>4 else bins
    outtext=f"""
    Input image: {coalesce(input, '(Not given)')}
    Mask image: {coalesce(mask, '(Not given)')}
    Mean normalization: {coalesce(mean, '(Not applied)')}
    Percentile: {thrp}-{uthrp}% (min-max)
    Histogram bins: {bininfo}
    Initial parameter: {np.array(params)}
    Parameter limit (min): {np.array(bounds[0])}
    Parameter limit (max): {np.array(bounds[1])}"""
    return outtext

def get_curve_fit_result_text(fitparam):
    outtexts=[]
    for i in range(fitparam.shape[0]):
        outtexts.append(f"""
        Curve {i+1}
        a{i+1}={fitparam[i, 0]}
        b{i+1}={fitparam[i, 1]}
        c{i+1}={fitparam[i, 2]}""")
    return outtexts

def save_curve_fit_text(settingtext, resulttexts, textfile):
    with open(textfile, "w") as o:
        print("### Initial setting", file=o)
        print(textwrap.dedent(settingtext).strip(), file=o)
        
        print("\n### Curve fit result", file=o)
        for text in resulttexts:
            print(textwrap.dedent(text).strip(), file=o) 
    return

def save_histogram_npy(bin_centers, bin_counts, outhist):
    out=np.c_[bin_centers, bin_counts].T
    np.save(outhist, out)
    return

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
    parser = argparse.ArgumentParser(
        description=__desc__, epilog=__epilog__, add_help=True, formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument('-v', '--version', action='version', version=f'%(prog)s {__version__}')
    parser.add_argument('--input', type=str, required=True, help='Input image')
    parser.add_argument('--curves', type=int, required=True, help='the number of curves for fitting')
    parser.add_argument('--mask', type=str, help='Mask image for curve fit')
    parser.add_argument('--norm', type=float, help='Divide input signal to adjust mean (in mask) to the following value')
    parser.add_argument('--thrp', type=float, default=0, help='threshold signals below the following percentile (default: 0)')
    parser.add_argument('--uthrp', type=float, default=100, help='threshold signals above the following percentile (default: 100)')
    parser.add_argument('--bin_width', type=float, help='Bin width of histogram')
    parser.add_argument('--bin_n', type=int, help='Number of bins')
    parser.add_argument('--bin_min', type=float, help='Lower limit of histogram')
    parser.add_argument('--bin_max', type=float, help='Upper limit of histogram')
    parser.add_argument('--paramset', type=str, default=os.path.join(os.path.dirname(__file__), "reference_policy.py"), help='Function file for parameter settings')
    parser.add_argument('--outfig', type=str, help='Save curve fit result as defined here')
    parser.add_argument('--outfigtype', type=int, default=1, help='Figure type setting(1: simple, 2: with parameters)')
    parser.add_argument('--outfigsize', type=float, default=4, help='Save curve fit result as defined here')
    parser.add_argument('--outtext', type=str, help='Save curve-fit-parameters text file as defined here')
    parser.add_argument('--outhist', type=str, help='Save histogram of raw data')

    args=parser.parse_args()
    
    inputfile=args.input
    maskfile=args.mask
    N_curve=args.curves
    M_norm=args.norm
    bin_width=args.bin_width
    bin_n=args.bin_n
    bin_min=args.bin_min
    bin_max=args.bin_max
    paramset=args.paramset
    thrp=args.thrp
    uthrp=args.uthrp
    outfig=args.outfig
    outfigtype=args.outfigtype
    outfigsize=args.outfigsize
    outtext=args.outtext
    outhist=args.outhist

    in_mat, in_header, in_affine=load_nifti(inputfile)
    if maskfile!=None:
        flag_mask=True
        mask_mat, mask_header, mask_affine=load_nifti(maskfile)

        if check_matrix_compatibility(in_mat, mask_mat)==False:
            raise InconsistentSpaceError("Matrix shapes are not compatible.")

        if check_header_compatibility(in_header, mask_header)==False:
            raise InconsistentSpaceError("Dimensions are not compatible.")

        if check_affine_compatibility(in_affine, mask_affine)==False:
            raise InconsistentSpaceError("Affine matrixs are not compatible.")

    else:
        flag_mask=False

    # Mask if necessary
    if flag_mask==True:
        in_mat=masking(in_mat, mask_mat)

    # Extract raw values
    values=in_mat[in_mat>0].reshape(-1)

    # Normalization by adjusting the mean if necessary
    if M_norm!=None:
        values=M_norm*values/np.mean(values)
    
    # Threshold by percentile
    values=within_percentile(values, thrp, uthrp)
    
    # Get histogram
    bin_counts, bin_edges=get_histogram(values, bin_width, bin_n, bin_min, bin_max)
    bin_centers=(bin_edges[:-1]+bin_edges[1:])/2

    # Import initial parameter function
    sys.dont_write_bytecode=True    # Suppress __pycache__ 
    spec=spec_from_file_location("refpolicy", paramset)
    module=module_from_spec(spec)
    spec.loader.exec_module(module)

    sys.modules['refpolicy']=module
    from refpolicy import determine_parameter

    # Set initial parameters
    initparam, param_bounds=determine_parameter(N_curve, bin_centers, bin_counts)
    
    # Print curve fit setting
    settingtext=get_curve_fit_setting_text(input=inputfile, mask=maskfile, mean=M_norm, thrp=thrp, uthrp=uthrp, bins=bin_centers, params=initparam, bounds=param_bounds)
    print(textwrap.dedent(settingtext).strip())
    
    # Curve fit
    fitparam=gmm_fit(bin_centers, bin_counts, n=N_curve, params=initparam, bounds=param_bounds)
    
    # Get summary text
    resulttexts=get_curve_fit_result_text(fitparam)
    mixture_curve=get_mixture_curve(bin_centers, fitparam)
    dice=calc_dice(bin_counts, mixture_curve)
    resulttexts.append(f"""
    Mixture Curve
    dice={dice}
    """)

    # Standard output Summary
    for text in resulttexts:
        print(textwrap.dedent(text).strip())

    # Save figure if necessary
    if outfig!=None:
        save_curve_fit_fig(bin_centers, bin_counts, fitparam, outfig, figsize=outfigsize, figtype=outfigtype)

    # Save parameters as .txt if necessary
    if outtext!=None:
        save_curve_fit_text(settingtext, resulttexts, outtext)

    # Save histogram as .npy if necessary
    if outhist!=None:
        save_histogram_npy(bin_centers, bin_counts, outhist)

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

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

### THAME-Q get_ref.py
### Objectives:
# This script is part of the THAME-Q pipeline and is responsible for determining data-driven reference values 
# through curve fitting based on signals within gray/white matter regions.

### Prerequisites:
# The following Python libraries are required:
#    - NumPy
#    - Nibabel
#    - Matplotlib
#    - Scipy

### Usage:
# Run the script using the following command:
# python get_ref.py [ID] [static PET image] [mask image specifying the target region] [output directory]
# The reference value will be returned as standard output.

### Main Outputs:
# - output_directory/${ID}_histogram.png: A visual representation of the curve fitting process used for signal value determination.
# - output_directory/${ID}_reference.nii: A voxel map image used for the final reference value determination.

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nemoto and K. Nakayama 11 Jul 2023

import os, sys
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit

# Usage: get_ref.py [ID] [PET image] [probability map] [output directory]

# Setting parameters
dsc_thr=0.936
bin_width=0.025
fwhm_area=1.0
histcutoff=0.5
weighting=True

def check_args(args):
  return True

def load_img(paths):
  out=[]
  for path in paths:
    out.append(nib.load(path).get_fdata())
  return out
  
def load_img_header(path):
  img=nib.load(path)
  return img.header
  
def load_img_affine(path):
  img=nib.load(path)
  return img.affine

def probmap2mask(probmap, msk_thr):
  msk=np.zeros(probmap.shape)
  msk[probmap>msk_thr]=1
  #msk=msk.astype(int)
  return msk

def get_erodedmap(img):
  a, b, c=img.shape
  img=np.pad(img, (1,))
  out=np.ones(img.size).reshape(img.shape)
  out[1:-1, 1:-1, 1:-1]=img[1:-1, 1:-1, 1:-1]
  
  for i in range(1, a+1):
    for j in range(1, b+1):
      for k in range(1, c+1):
        out[i, j, k]=np.min([img[i, j, k], img[i-1, j, k], img[i+1, j, k], img[i, j-1, k], img[i, j+1, k]])
        
  return out[1:-1, 1:-1, 1:-1]

def get_values_in_mask(img, msk):
  maskedimg=img*msk
  maskedvalue=maskedimg.reshape(-1)
  value=maskedvalue[np.nonzero(maskedvalue)]
  return value

def data2dist(data, w):
  x=np.array([i*w for i in range(int(1+np.max(data)//w))])
  y=np.zeros(x.size)
  for d in data:
    y[int(d//w)]+=1
    
  i=0
  while y[i]<1:
    i+=1
  j=int(np.max(data)//w)
  while y[j]<1:
    j-=1
  x+=w/2
  return x[i:j+1], y[i:j+1]

def func_mono(x, *param):
  y1=param[0]*np.exp(-pow((x-param[1])/param[2], 2)/2)/pow(2*np.pi, 1/2)/param[2]
  return y1

def func_bi(x, *param):
  y1=param[0]*np.exp(-pow((x-param[1])/param[2], 2)/2)/pow(2*np.pi, 1/2)/param[2]
  y2=param[3]*np.exp(-pow((x-param[4])/param[5], 2)/2)/pow(2*np.pi, 1/2)/param[5]
  ys=y1+y2
  return ys

def get_gaussian(a, b, c):
  def gaussian(x):
    return a*np.exp(-pow((x-b)/c, 2)/2)/pow(2*np.pi, 1/2)/c
  return gaussian

def calc_dsc(x, y, gm):
  return 2*np.sum([np.min([gm(xi), yi]) for xi, yi in zip(x, y)])/(np.sum([gm(xi) for xi in x])+np.sum(y))

def calc_FWHM(mu, sigma, area=fwhm_area):
  FWHM_min=mu-sigma*pow(2*np.log(2), 1/2)*area
  FWHM_max=mu+sigma*pow(2*np.log(2), 1/2)*area
  return FWHM_min, FWHM_max

def calc_refval_mono(values, lim_min, lim_max):
  values[values<lim_min]=0
  values[values>lim_max]=0
  values=values[np.nonzero(values)]
  refnum=len(values)
  refval=np.mean(values)
  return refnum, refval

def calc_refval_bi(values, g1, g2, lim_min, lim_max):
  values[values<lim_min]=0
  values[values>lim_max]=0
  values=values[np.nonzero(values)]
  refnum=len(values)
  #weights=[g1(vi)/(g1(vi)+g2(vi)) for vi in values]
  #refval=np.sum([vi*wi for vi, wi in zip(values, weights)])/np.sum(weights)
  weights=g1(values)/(g1(values)+g2(values))
  refval=np.dot(weights, values)/np.sum(weights)
  return refnum, refval

def bimodal_curve_fitting(x, y, params, param_bounds):
  popt, pcov=curve_fit(func_bi, x, y, p0=params, bounds=param_bounds)
  if popt[1]>popt[4]:
    popt=popt[[3, 4, 5, 0, 1, 2]]
  FWHM_min, FWHM_max=calc_FWHM(popt[1], popt[2])
  if FWHM_max<x[0]:
    raise Exception('InadequateFitting')
  return popt
  
def monomodal_curve_fitting(x, y):
  popt_mono, pcov_mono=curve_fit(func_mono, x, y, p0=[np.max(y), x[np.argmax(y)], 0.5], bounds=[[0, x[0], 0], [np.inf, x[-1], np.inf]])
  return popt_mono

def save_figure(x, y, a1, b1, c1, a2, b2, c2, am, bm, cm, dsc, refnum, refval, dsc_thr, ID, output_directory):
  if dsc<0:
    save_figure_b(x, y, a1, b1, c1, a2, b2, c2, refnum, refval, ID, output_directory)
  else:
    save_figure_bm(x, y, a1, b1, c1, a2, b2, c2, am, bm, cm, dsc, refnum, refval, dsc_thr, ID, output_directory)
    
def save_figure_b(x, y, a1, b1, c1, a2, b2, c2, refnum, refval, ID, output_directory):
  g1=get_gaussian(a1, b1, c1)
  g2=get_gaussian(a2, b2, c2)
  
  fig=plt.figure(figsize=(13, 4))
  ax1=fig.add_subplot(1, 3, 1)
  ax1.plot(x, y, c='black', label='original')
  ax1.set_title(ID, size=15)
  ax1.set_ylabel('frequency', size=15)
  ax1.text(0.5, 0.7, 'voxel num: \n  '+str(np.sum(y).astype(int)), transform=ax1.transAxes, size=15)
  
  ax2=fig.add_subplot(1, 3, 2)
  ax2.plot(x, y, c='black', alpha=0.3, label='original')
  ax2.plot(x, g1(x), c='blue', alpha=0.8, label='g1')
  ax2.plot(x, g2(x), c='green', alpha=0.8, label='g2')
  ax2.plot(x, g1(x)+g2(x), c='red', label='g1+g2')
  l2=ax2.legend()
  l2.set_zorder(1)
  ax2.set_title('bimodal fitting', size=15)
  ax2.set_xlabel('value', size=15)
  ax2.text(0.6, 0.58, 'refnum: '+str(refnum), transform=ax2.transAxes)
  ax2.text(0.6, 0.52, '  a1  : '+'{:.2f}'.format(a1), transform=ax2.transAxes)
  ax2.text(0.6, 0.46, ' mu1  : '+'{:.3f}'.format(b1), transform=ax2.transAxes)
  ax2.text(0.6, 0.40, 'std1  : '+'{:.3f}'.format(c1), transform=ax2.transAxes)
  ax2.text(0.6, 0.32, ' a2   : '+'{:.2f}'.format(a2), transform=ax2.transAxes)
  ax2.text(0.6, 0.26, ' mu2  : '+'{:.3f}'.format(b2), transform=ax2.transAxes)
  ax2.text(0.6, 0.20, 'std2  : '+'{:.3f}'.format(c2), transform=ax2.transAxes)
  ax2.text(0.3, 0.8, 'SELECTED\n refval=''{:.3f}'.format(refval), size=18, color='magenta', transform=ax2.transAxes, zorder=2)
  
  ax3=fig.add_subplot(1, 3, 3)
  ax3.text(0.35, 0.5, 'No Data', size=15, transform=ax3.transAxes)
  ax3.set_title('monomodal fitting', size=15)
  
  plt.savefig(os.path.join(output_directory, ID+'_histogram.jpeg'))
  return

def save_figure_bm(x, y, a1, b1, c1, a2, b2, c2, am, bm, cm, dsc, refnum, refval, dsc_thr, ID, output_directory):
  g1=get_gaussian(a1, b1, c1)
  g2=get_gaussian(a2, b2, c2)
  gm=get_gaussian(am, bm, cm)
  
  fig=plt.figure(figsize=(13, 4))
  ax1=fig.add_subplot(1, 3, 1)
  ax1.plot(x, y, c='black', label='original')
  ax1.set_title(ID, size=15)
  ax1.set_ylabel('frequency', size=15)
  ax1.text(0.5, 0.7, 'voxel num: \n  '+str(np.sum(y).astype(int)), transform=ax1.transAxes, size=15)
  
  ax2=fig.add_subplot(1, 3, 2)
  ax2.plot(x, y, c='black', alpha=0.3, label='original')
  ax2.plot(x, g1(x), c='blue', alpha=0.8, label='g1')
  ax2.plot(x, g2(x), c='green', alpha=0.8, label='g2')
  ax2.plot(x, g1(x)+g2(x), c='red', label='g1+g2')
  l2=ax2.legend()
  l2.set_zorder(1)
  ax2.set_title('bimodal fitting', size=15)
  ax2.set_xlabel('value', size=15)
  #ax2.text(0.6, 0.58, 'refnum: '+'{:.2f}'.format(refnum), transform=ax2.transAxes)
  ax2.text(0.6, 0.52, '  a1  : '+'{:.2f}'.format(a1), transform=ax2.transAxes)
  ax2.text(0.6, 0.46, ' mu1  : '+'{:.3f}'.format(b1), transform=ax2.transAxes)
  ax2.text(0.6, 0.40, 'std1  : '+'{:.3f}'.format(c1), transform=ax2.transAxes)
  ax2.text(0.6, 0.32, ' a2   : '+'{:.2f}'.format(a2), transform=ax2.transAxes)
  ax2.text(0.6, 0.26, ' mu2  : '+'{:.3f}'.format(b2), transform=ax2.transAxes)
  ax2.text(0.6, 0.20, 'std2  : '+'{:.3f}'.format(c2), transform=ax2.transAxes)
  
  ax3=fig.add_subplot(1, 3, 3)
  ax3.plot(x, y, c='black', alpha=0.3, label='original')
  ax3.plot(x, gm(x), c='orange', alpha=0.8, label='gm')
  l3=ax3.legend()
  l3.set_zorder(1)
  ax3.set_title('monomodal fitting', size=15)
  #ax3.text(0.6, 0.58, 'refnum: '+'{:.2f}'.format(refnum), transform=ax3.transAxes)
  ax3.text(0.6, 0.52, '   a  : '+'{:.2f}'.format(am), transform=ax3.transAxes)
  ax3.text(0.6, 0.46, '  mu  : '+'{:.3f}'.format(bm), transform=ax3.transAxes)
  ax3.text(0.6, 0.40, ' std  : '+'{:.3f}'.format(cm), transform=ax3.transAxes)
  ax3.text(0.6, 0.34, ' dice : '+'{:.3f}'.format(dsc), transform=ax3.transAxes)
  
  if dsc<dsc_thr:
    ax2.text(0.1, 0.8, 'SELECTED\n refval=''{:.3f}'.format(refval), size=18, color='magenta', transform=ax2.transAxes, zorder=2)
    ax2.text(0.6, 0.58, 'refnum: '+str(refnum), transform=ax2.transAxes)
  else:
    ax3.text(0.1, 0.8, 'SELECTED\n refval=''{:.3f}'.format(refval), size=18, color='magenta', transform=ax3.transAxes, zorder=2)
    ax3.text(0.6, 0.58, 'refnum: '+str(refnum), transform=ax3.transAxes)
  
  plt.savefig(os.path.join(output_directory, ID+'_histogram.jpeg'))
  return

def save_parameters(data, txtfile):
  f=open(txtfile, 'a', encoding='UTF-8')
  for d in data[:-1]:
    f.write(str(d))
    f.write('\t')
  f.write(str(data[-1]))
  f.write('\n')
  f.close()
  return
  
def save_refnii_bi(img, g1, g2, llim, ulim, w, h, a, fname):
  if w==False:
    save_refnii_mono(img, llim, ulim, h, a, fname)
    return
  else:
    weights=img.copy()
    weights[img<llim]=ulim
    weights[img>ulim]=ulim
    weights=g1(weights)/(g1(weights)+g2(weights))
    weights[img<llim]=0
    weights[img>ulim]=0
    reference_nii=nib.Nifti1Image(weights, header=h, affine=a)
    nib.save(reference_nii, fname)
  return
  
def save_refnii_mono(img, llim, ulim, h, a, fname):
  img[img<llim]=0
  img[img>ulim]=0
  img[img>0]=1
  reference_nii=nib.Nifti1Image(img, header=h, affine=a)
  nib.save(reference_nii, fname)
  return

def get_tertile(y):
  # Cumulative distribution
  y=np.append(0, y)
  for i in range(len(y)-1):
    y[i+1]+=y[i]
    
  for i in range(len(y)):
    if y[i]/y[-1]<1/3: t1=i
    if y[i]/y[-1]<2/3: t2=i
    
  return max(0, t1-1), max(0, t2-1)
  
if __name__ == '__main__':
  # Check input variables
  args=sys.argv
  if check_args(args):
    ID=args[1]
    pet, probmap=load_img(args[2:4])
    img_header=load_img_header(args[3])
    img_affine=load_img_affine(args[3])
    output_directory=args[4]
  else:
    exit()
  
  # Convert probability map to mask image
  #eroded_probmap=get_erodedmap(probmap)
  msk=probmap.copy()
  msk[msk<0.9]=0
  msk[msk>0]=1
  
  # Get PET values inside the mask
  pet_gm=get_values_in_mask(pet, msk)
  x, y=data2dist(pet_gm, bin_width)
  
  # Bimodal Curve Fitting
  #params=[pow(2*np.pi, 1/2)*np.max(y)/2, 1.0, 0.2, pow(2*np.pi, 1/2)*np.max(y)/2, 1.5, 0.2]
  t1, t2=get_tertile(y)
  list_params=[
    [np.max(y)/2, 1.0, 0.2, np.max(y)/2, 1.5, 0.2],
    [np.max(y)/2, x[t1], 0.2, np.max(y)/2, x[t2], 0.2],
    [np.max(y)*0.66, x[np.argmax(y)], 0.2, np.max(y)*0.34, x[np.argmax(y)], 0.2],
    [np.max(y)*0.66, x[t1], 0.2, np.max(y)*0.34, x[t2], 0.2],
    [np.max(y)/2, 1.0, 0.2, np.max(y)/2, 1.5, 0.2],
    [np.max(y)/2, x[t1], 0.2, np.max(y)/2, x[t2], 0.2],
    [np.max(y)*0.66, x[np.argmax(y)], 0.2, np.max(y)*0.34, x[np.argmax(y)], 0.2],
    [np.max(y)*0.66, x[t1], 0.2, np.max(y)*0.34, x[t2], 0.2],
  ]
  list_param_bounds=[
    [[0]*6, [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0]*6, [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0]*6, [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0]*6, [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0, x[0], 0, 0, x[0], 0], [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0, x[0], 0, 0, x[0], 0], [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0, x[0], 0, 0, x[0], 0], [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
    [[0, x[0], 0, 0, x[0], 0], [1.5*np.max(y), 5, 5, 1.5*np.max(y), 10, 5]],
  ]
  
  for params, param_bounds in zip(list_params, list_param_bounds):
    try:
      a1, b1, c1, a2, b2, c2=bimodal_curve_fitting(x, y, params, param_bounds)
    except:
      continue
    else:
      break
  else:
    # Error at Curve Fitting
    sys.stdout.write('0')
    exit()
  
  g1=get_gaussian(a1, b1, c1)
  g2=get_gaussian(a2, b2, c2)
  
  # Monomodal Curve Fitting if necessary
  if g1(b1)<g2(b2)*histcutoff:
    am, bm, cm=monomodal_curve_fitting(x, y)
    gm=get_gaussian(am, bm, cm)
    dsc=calc_dsc(x, y, gm)
  else:
    am, bm, cm=0, 0, 0
    dsc=-1
  
  # Calculate FWHM range and reference value.
  if dsc<dsc_thr:
    FWHM_min, FWHM_max=calc_FWHM(b1, c1)
    if weighting==True:
      refnum, refval=calc_refval_bi(pet_gm, g1, g2, FWHM_min, FWHM_max)
    else:
      refnum, refval=calc_refval_mono(pet_gm, FWHM_min, FWHM_max)
  else:
    FWHM_min, FWHM_max=calc_FWHM(bm, cm)
    refnum, refval=calc_refval_mono(pet_gm, FWHM_min, FWHM_max)

  # Output histogram figure
  save_figure(x, y, a1, b1, c1, a2, b2, c2, am, bm, cm, dsc, refnum, refval, dsc_thr, ID, output_directory)
  
  # Output reference image and histogram parameters
  if dsc<dsc_thr:
    save_refnii_bi(pet*msk, g1, g2, FWHM_min, FWHM_max, weighting, img_header, img_affine, os.path.join(output_directory, ID+'_reference.nii'))
    save_parameters([ID, args[3], len(pet_gm), a1, b1, c1, a2, b2, c2, FWHM_min, FWHM_max, refnum, refval], os.path.join(output_directory, 'histogram_parameters.txt'))
  else:
    save_refnii_mono(pet*msk, FWHM_min, FWHM_max, img_header, img_affine, os.path.join(output_directory, ID+'_reference.nii'))
    save_parameters([ID, args[3], len(pet_gm), am, bm, cm, 0, 0, 0, FWHM_min, FWHM_max, refnum, refval], os.path.join(output_directory, 'histogram_parameters.txt'))

  sys.stdout.write(str(refval))
  exit()

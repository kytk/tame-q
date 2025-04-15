#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from scipy.ndimage import zoom

def pad2square(mat):
    n, m=mat.shape
    size=max(n, m)
    
    pad_top=(size-n)//2
    pad_bottom=size-n-pad_top
    pad_left=(size-m)//2
    pad_right=size-m-pad_left
    
    padded=np.pad(mat, ((pad_top, pad_bottom), (pad_left, pad_right)), mode='constant')
    
    return padded

def pad2square_pixdim(mat, pixdims):
    L1=pixdims[0]*mat.shape[0]
    L2=pixdims[1]*mat.shape[1]
    size=max(L1, L2)

    pad_top=((size-L1)/pixdims[0])//2
    pad_bottom=(size-L1-pixdims[0]*pad_top)//pixdims[0]
    pad_left=((size-L2)/pixdims[1])//2
    pad_right=(size-L2-pixdims[1]*pad_left)//pixdims[1]

    padded=np.pad(mat, ((pad_top.astype('int16'), pad_bottom.astype('int16')), (pad_left.astype('int16'), pad_right.astype('int16'))), mode='constant')
    return padded

def adjust_size(mat, s=200):
    padded=pad2square(mat)
    adjusted=zoom(padded, zoom=s/padded.shape[0], order=1)
    return adjusted

def adjust_size_pixdim(mat, pixdims, s=200):
    padded=pad2square_pixdim(mat, pixdims)
    adjusted=zoom(padded, zoom=s/padded.shape[0], order=1)
    return adjusted

def get_centroid(mat):
    centroid = [np.average(c, weights=mass) for c in np.indices(mat.shape)]
    return tuple(centroid)

ID=sys.argv[1]
t1w=sys.argv[2]
pet_mean=sys.argv[3]
pet_dyn=sys.argv[4]
pet_ref=sys.argv[5]
out=sys.argv[6]

img_t1w=nib.load(t1w).get_fdata()
img_pet=nib.load(pet_mean).get_fdata()
img_dyn=np.pad(nib.load(pet_dyn).get_fdata(), pad_width=((1, 1), (1, 1), (1, 1), (0, 0)), mode='constant')
img_ref=np.pad(nib.load(pet_ref).get_fdata(), pad_width=((1, 1), (1, 1), (1, 1)), mode='constant')

#FOV
head_pet=nib.load(pet_mean).header
fov=head_pet['pixdim'][1:4]*head_pet['dim'][1:4]

l=nib.load(pet_ref).header['pixdim'][1:4]
size=(fov//l).astype('int16')

xaxis_sum=img_ref.sum(axis=1).sum(axis=1)
yaxis_sum=img_ref.sum(axis=2).sum(axis=0)
zaxis_sum=img_ref.sum(axis=0).sum(axis=0)

Gx=np.average(np.arange(xaxis_sum.size), weights=xaxis_sum)
Gy=np.average(np.arange(yaxis_sum.size), weights=yaxis_sum)
Gz=np.average(np.arange(zaxis_sum.size), weights=zaxis_sum)

img_ref=img_ref[max(int(Gx-size[0]/2), 0):min(int(Gx+size[0]/2), int(img_ref.shape[0]-1)), max(int(Gy-size[1]/2), 0):min(int(Gy+size[1]/2), int(img_ref.shape[1]-1)), max(int(Gz-size[2]/2), 0):min(int(Gz+size[2]/2), int(img_ref.shape[2]-1))]
img_dyn=img_dyn[max(int(Gx-size[0]/2), 0):min(int(Gx+size[0]/2), int(img_dyn.shape[0]-1)), max(int(Gy-size[1]/2), 0):min(int(Gy+size[1]/2), int(img_dyn.shape[1]-1)), max(int(Gz-size[2]/2), 0):min(int(Gz+size[2]/2), int(img_dyn.shape[2]-1)), :]

# Crop
fig=plt.figure(figsize=(8.27, 11.69), dpi=300, facecolor='white')
fig.text(0.5, 0.93, "QA Report: Realignment and Coregistration", size=20, ha='center', weight='bold')
fig.text(0.08, 0.9, ID, size=14)
#1
ax1=fig.add_axes((0.15, 0.75, 0.82, 0.14))
fig.text(0.075, 0.82, 'Averaged PET\non T1W', ha='center', va='center')
idx1=img_t1w.shape[0]//4
idx2=img_t1w.shape[0]//2
idx3=idx1+idx2
mat_t1w_1=adjust_size(img_t1w[idx1, ::-1, ::-1].transpose(1, 0))
mat_t1w_2=adjust_size(img_t1w[idx2, ::-1, ::-1].transpose(1, 0))
mat_t1w_3=adjust_size(img_t1w[idx3, ::-1, ::-1].transpose(1, 0))
mat_t1w_4=adjust_size(img_t1w[:, img_t1w.shape[1]//2, ::-1].transpose(1, 0))
mat_t1w_5=adjust_size(img_t1w[:, ::-1, img_t1w.shape[2]//2].transpose(1, 0))
mat_t1w=np.c_[mat_t1w_1, mat_t1w_2, mat_t1w_3, mat_t1w_4, mat_t1w_5]

mat_pet_1=adjust_size(img_pet[idx1, ::-1, ::-1].transpose(1, 0))
mat_pet_2=adjust_size(img_pet[idx2, ::-1, ::-1].transpose(1, 0))
mat_pet_3=adjust_size(img_pet[idx3, ::-1, ::-1].transpose(1, 0))
mat_pet_4=adjust_size(img_pet[:, img_pet.shape[1]//2, ::-1].transpose(1, 0))
mat_pet_5=adjust_size(img_pet[:, ::-1, img_pet.shape[2]//2].transpose(1, 0))
mat_pet=np.c_[mat_pet_1, mat_pet_2, mat_pet_3, mat_pet_4, mat_pet_5]

ax1.imshow(mat_t1w, cmap='gray')
msk=ax1.imshow(mat_pet, cmap='jet', alpha=0.4).set_clim(0.1, mat_pet.max())

ax1.axes.xaxis.set_visible(False)
ax1.axes.yaxis.set_visible(False)

#2
ax2=fig.add_axes((0.15, 0.61, 0.82, 0.14))
fig.text(0.075, 0.68, 'Target image\nfor alignment', ha='center', va='center')
idx4=img_ref.shape[0]//4
idx3=img_ref.shape[0]//3
idx2=img_ref.shape[0]//2
mat_ref_1=adjust_size_pixdim(img_ref[idx4, ::-1, ::-1].transpose(1, 0), [l[2], l[1]])
mat_ref_2=adjust_size_pixdim(img_ref[idx3, ::-1, ::-1].transpose(1, 0), [l[2], l[1]])
mat_ref_3=adjust_size_pixdim(img_ref[idx2, ::-1, ::-1].transpose(1, 0), [l[2], l[1]])
mat_ref_4=adjust_size_pixdim(img_ref[-idx3, ::-1, ::-1].transpose(1, 0), [l[2], l[1]])
mat_ref_5=adjust_size_pixdim(img_ref[-idx4, ::-1, ::-1].transpose(1, 0), [l[2], l[1]])
mat_ref=np.c_[mat_ref_1, mat_ref_2, mat_ref_3, mat_ref_4, mat_ref_5]
ax2.imshow(mat_ref, cmap='gray', aspect=l[2]/l[1])

ax2.axes.xaxis.set_visible(False)
ax2.axes.yaxis.set_visible(False)

#3
ax3=fig.add_axes((0.15, 0.47, 0.82, 0.14))
fig.text(0.075, 0.54, 'Frame1\non\nTarget image', ha='center', va='center')
mat_dyn1_1=adjust_size_pixdim(img_dyn[idx4, ::-1, ::-1, 0].transpose(1, 0), [l[2], l[1]])
mat_dyn1_2=adjust_size_pixdim(img_dyn[idx3, ::-1, ::-1, 0].transpose(1, 0), [l[2], l[1]])
mat_dyn1_3=adjust_size_pixdim(img_dyn[idx2, ::-1, ::-1, 0].transpose(1, 0), [l[2], l[1]])
mat_dyn1_4=adjust_size_pixdim(img_dyn[-idx3, ::-1, ::-1, 0].transpose(1, 0), [l[2], l[1]])
mat_dyn1_5=adjust_size_pixdim(img_dyn[-idx4, ::-1, ::-1, 0].transpose(1, 0), [l[2], l[1]])
mat_dyn1=np.c_[mat_dyn1_1, mat_dyn1_2, mat_dyn1_3, mat_dyn1_4, mat_dyn1_5]

ax3.imshow(mat_ref, cmap='gray', aspect=l[2]/l[1])
ax3.imshow(mat_dyn1, cmap='jet', aspect=l[2]/l[1], alpha=0.4).set_clim(0, mat_ref.max())

ax3.axes.xaxis.set_visible(False)
ax3.axes.yaxis.set_visible(False)

#4
ax4=fig.add_axes((0.15, 0.33, 0.82, 0.14))
fig.text(0.075, 0.40, 'Frame2\non\nTarget image', ha='center', va='center')
mat_dyn2_1=adjust_size_pixdim(img_dyn[idx4, ::-1, ::-1, 1].transpose(1, 0), [l[2], l[1]])
mat_dyn2_2=adjust_size_pixdim(img_dyn[idx3, ::-1, ::-1, 1].transpose(1, 0), [l[2], l[1]])
mat_dyn2_3=adjust_size_pixdim(img_dyn[idx2, ::-1, ::-1, 1].transpose(1, 0), [l[2], l[1]])
mat_dyn2_4=adjust_size_pixdim(img_dyn[-idx3, ::-1, ::-1, 1].transpose(1, 0), [l[2], l[1]])
mat_dyn2_5=adjust_size_pixdim(img_dyn[-idx4, ::-1, ::-1, 1].transpose(1, 0), [l[2], l[1]])
mat_dyn2=np.c_[mat_dyn2_1, mat_dyn2_2, mat_dyn2_3, mat_dyn2_4, mat_dyn2_5]

ax4.imshow(mat_ref, cmap='gray', aspect=l[2]/l[1])
ax4.imshow(mat_dyn2, cmap='jet', aspect=l[2]/l[1], alpha=0.4).set_clim(0, mat_ref.max())

ax4.axes.xaxis.set_visible(False)
ax4.axes.yaxis.set_visible(False)

#5
ax5=fig.add_axes((0.15, 0.19, 0.82, 0.14))
fig.text(0.075, 0.26, 'Frame3\non\nTarget image', ha='center', va='center')
mat_dyn3_1=adjust_size_pixdim(img_dyn[idx4, ::-1, ::-1, 2].transpose(1, 0), [l[2], l[1]])
mat_dyn3_2=adjust_size_pixdim(img_dyn[idx3, ::-1, ::-1, 2].transpose(1, 0), [l[2], l[1]])
mat_dyn3_3=adjust_size_pixdim(img_dyn[idx2, ::-1, ::-1, 2].transpose(1, 0), [l[2], l[1]])
mat_dyn3_4=adjust_size_pixdim(img_dyn[-idx3, ::-1, ::-1, 2].transpose(1, 0), [l[2], l[1]])
mat_dyn3_5=adjust_size_pixdim(img_dyn[-idx4, ::-1, ::-1, 2].transpose(1, 0), [l[2], l[1]])
mat_dyn3=np.c_[mat_dyn3_1, mat_dyn3_2, mat_dyn3_3, mat_dyn3_4, mat_dyn3_5]

ax5.imshow(mat_ref, cmap='gray', aspect=l[2]/l[1])
ax5.imshow(mat_dyn3, cmap='jet', aspect=l[2]/l[1], alpha=0.4).set_clim(0, mat_ref.max())

ax5.axes.xaxis.set_visible(False)
ax5.axes.yaxis.set_visible(False)

#6
ax6=fig.add_axes((0.15, 0.05, 0.82, 0.14))
fig.text(0.075, 0.12, 'Frame4\non\nTarget image', ha='center', va='center')
mat_dyn4_1=adjust_size_pixdim(img_dyn[idx4, ::-1, ::-1, 3].transpose(1, 0), [l[2], l[1]])
mat_dyn4_2=adjust_size_pixdim(img_dyn[idx3, ::-1, ::-1, 3].transpose(1, 0), [l[2], l[1]])
mat_dyn4_3=adjust_size_pixdim(img_dyn[idx2, ::-1, ::-1, 3].transpose(1, 0), [l[2], l[1]])
mat_dyn4_4=adjust_size_pixdim(img_dyn[-idx3, ::-1, ::-1, 3].transpose(1, 0), [l[2], l[1]])
mat_dyn4_5=adjust_size_pixdim(img_dyn[-idx4, ::-1, ::-1, 3].transpose(1, 0), [l[2], l[1]])
mat_dyn4=np.c_[mat_dyn4_1, mat_dyn4_2, mat_dyn4_3, mat_dyn4_4, mat_dyn4_5]

ax6.imshow(mat_ref, cmap='gray', aspect=l[2]/l[1])
ax6.imshow(mat_dyn4, cmap='jet', aspect=l[2]/l[1], alpha=0.4).set_clim(0, mat_ref.max())

ax6.axes.xaxis.set_visible(False)
ax6.axes.yaxis.set_visible(False)

fig.savefig(out)
exit()

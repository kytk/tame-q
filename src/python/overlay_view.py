#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt

def tiling(mat):
  global X, Y
  s, t=mat.shape[1], mat.shape[0]
  out=np.zeros((s*X, t*Y))
  for i in range(X):
    for j in range(Y):
      out[i*s:(i+1)*s, j*t:(j+1)*t]=mat[:, ::-1, i*Y+j].T
  return out

X=6
Y=5
START=20
INTERVAL=4

ID=sys.argv[1]
t1w=sys.argv[2]
pet=sys.argv[3]
thr=float(sys.argv[4])
uthr=float(sys.argv[5])
out_t1=sys.argv[6]
out_pmpbb3=sys.argv[7]

img_t1w=nib.load(t1w).get_fdata()
img_pet=nib.load(pet).get_fdata()

mat_t1w=tiling(img_t1w[:, :, START:START+INTERVAL*(X*Y):INTERVAL])
mat_pet=tiling(img_pet[:, :, START:START+INTERVAL*(X*Y):INTERVAL])

# T1W images
fig=plt.figure(figsize=(8.27, 11.69), dpi=600, facecolor='white')
ax=fig.add_axes((0.03, 0.13, 0.94, 0.8))
ax.imshow(mat_t1w, cmap='gray')

ax.axes.xaxis.set_visible(False)
ax.axes.yaxis.set_visible(False)

fig.text(0.6, 0.09, ID, size=20)
fig.savefig(out_t1)

# PMPBB3 images on T1W images
fig=plt.figure(figsize=(8.27, 11.69), dpi=600, facecolor='white')
ax=fig.add_axes((0.03, 0.13, 0.94, 0.8))
ax.imshow(mat_t1w, cmap='gray')
msk=ax.imshow(mat_pet, cmap='jet', alpha=0.4)
msk.set_clim(thr, uthr)

ax.axes.xaxis.set_visible(False)
ax.axes.yaxis.set_visible(False)

cax=fig.add_axes((0.11, 0.09, 0.4, 0.03))
fig.colorbar(msk, orientation='horizontal', cax=cax)

fig.text(0.6, 0.09, ID, size=20)
fig.savefig(out_pmpbb3)

exit()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, os
import numpy as np
import nibabel as nib

def compute_centroid(img):
    data=img.get_fdata()
    coords=np.array(np.nonzero(data))
    centroid_voxel=coords.mean(axis=1)
    centroid=nib.affines.apply_affine(img.affine, centroid_voxel)
    return centroid

input=sys.argv[1]
target=sys.argv[2]
output=sys.argv[3]

# Load images
target_img=nib.load(target)
input_img=nib.load(input)

# Calculate centroid
target_centroid=compute_centroid(target_img)
input_centroid=compute_centroid(input_img)

# Calculate vector
translation=target_centroid-input_centroid
affine = input_img.affine.copy()
affine[:3, 3] += translation

# Output
output_img = nib.Nifti1Image(input_img.get_fdata(), affine, header=input_img.header)
nib.save(output_img, output)

exit()
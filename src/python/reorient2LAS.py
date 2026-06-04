#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import numpy as np
import nibabel as nib
import sys
from nibabel.orientations import (
    io_orientation, axcodes2ornt, ornt_transform, apply_orientation, inv_ornt_aff
)

def reorient_to_axcodes(img: nib.Nifti1Image, target_axcodes=('L','A','S')) -> nib.Nifti1Image:
    """
    Reorient a NIfTI image to target axis codes (e.g., LAS) by modifying both data and affine consistently.
    """
    
    orig_zooms = img.header.get_zooms()
    
    if img.ndim != 3 and img.ndim != 4:
        raise ValueError(f"Only 3D/4D images are supported, got ndim={img.ndim}")

    # 1) current orientation from affine
    cur_ornt = io_orientation(img.affine)

    # 2) target orientation from axcodes
    tar_ornt = axcodes2ornt(target_axcodes)

    # 3) transform from current -> target
    transform = ornt_transform(cur_ornt, tar_ornt)

    # 4) reorient data (apply to spatial axes only)
    data = img.get_fdata(dtype=np.float32)
    new_data = apply_orientation(data, transform)
    
    # 5) update affine so world coordinates remain consistent
    new_affine = img.affine @ inv_ornt_aff(transform, img.shape[:3])

    # 6) build new image + make qform/sform consistent
    new_hdr = img.header.copy()
    out = nib.Nifti1Image(new_data, new_affine, header=new_hdr)

    # set both sform/qform to new affine (codes: 1=SCANNER_ANAT is a common safe default)
    out.set_sform(new_affine, code=1)
    out.set_qform(new_affine, code=1)
    
    out.header.set_zooms(orig_zooms)

    return out

# usage
img = nib.load(sys.argv[1])
out = reorient_to_axcodes(img, ('L','A','S'))
nib.save(out, sys.argv[2])

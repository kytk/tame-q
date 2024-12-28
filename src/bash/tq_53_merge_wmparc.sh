#!/bin/bash

# Merge wmparc ROIs for the volume stability.

# This script merge ROIs as below:
# 1. caudalmiddlefrontal (?003), rostralmiddlefrontal (?027) --> middlefrontal(?003)
# 2. parsopercularis (?018), parstriangularis (?019), parsorbitalis (?020) --> inferiorfrontal (?018)
# 3. lateralorbitofrontal (?012), medialorbitofrontal (?014), frontalpole (?032) --> orbitofrontal (?012)
# 4. caudalanteriorcingulate (?002), isthmuscingulate (?010), posteriorcingulate (?023), rostralanteriorcingulate (?026) --> cingulate

# K. Nakayama 08 Aug 2024

# For debugging
#set -x

for f in *_wmparc_r.nii.gz
do
  echo "Get merged wmparc from ${f} "

  # middlefrontal
  f_merged=${f/wmparc/wmparc_merged}
  fslmaths ${f} -thr 1000 -rem 1000 -thr 27 -uthr 27 -sub 3 -thr 0 tmp4sub
  fslmaths ${f} -sub tmp4sub ${f_merged}
  
  #inferiorfrontal
  fslmaths ${f} -thr 1000 -rem 1000 -thr 19 -uthr 20 -sub 18 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #orbitofrontal (medialorbitofraonal)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 14 -uthr 14 -sub 12 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #orbitofrontal (frontalpole)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 32 -uthr 32 -sub 12 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #cingulate(isthmuscingulate)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 10 -uthr 10 -sub 2 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #cingulate(poasteriorcingulate)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 23 -uthr 23 -sub 2 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #cingulate(rostralanteriorcingulate)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 26 -uthr 26 -sub 2 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  echo "Save ${f_merged}"
  
  rm tmp4sub.nii.gz
done


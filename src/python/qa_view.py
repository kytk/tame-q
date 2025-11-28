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

def adjust_size(mat, s=200, interp=1):
    padded=pad2square(mat)
    adjusted=zoom(padded, zoom=s/padded.shape[0], order=interp)
    return adjusted

def adjust_size_pixdim(mat, pixdims, s=200, interp=1):
    padded=pad2square_pixdim(mat, pixdims)
    adjusted=zoom(padded, zoom=s/padded.shape[0], order=interp)
    return adjusted

def get_display_indexes(img, n=5):
    tmp=img.max(axis=0).max(axis=0)
    nonzeroidxes=np.where(tmp>0)[0]
    steprange=(nonzeroidxes[-1]-nonzeroidxes[0])//(n+1)
    return [nonzeroidxes[0]+(i+1)*steprange for i in range(n)]

def get_mat_t1w_pet(img_t1w, img_pet, img_t1w_outline):
    idxes=get_display_indexes(img_t1w_outline)
    
    mat_t1w_1=adjust_size(img_t1w[:, ::-1, idxes[0]].transpose(1, 0))
    mat_t1w_2=adjust_size(img_t1w[:, ::-1, idxes[1]].transpose(1, 0))
    mat_t1w_3=adjust_size(img_t1w[:, ::-1, idxes[2]].transpose(1, 0))
    mat_t1w_4=adjust_size(img_t1w[:, ::-1, idxes[3]].transpose(1, 0))
    mat_t1w_5=adjust_size(img_t1w[:, ::-1, idxes[4]].transpose(1, 0))
    mat_t1w=np.c_[mat_t1w_1, mat_t1w_2, mat_t1w_3, mat_t1w_4, mat_t1w_5]

    mat_pet_1=adjust_size(img_pet[:, ::-1, idxes[0]].transpose(1, 0))
    mat_pet_2=adjust_size(img_pet[:, ::-1, idxes[1]].transpose(1, 0))
    mat_pet_3=adjust_size(img_pet[:, ::-1, idxes[2]].transpose(1, 0))
    mat_pet_4=adjust_size(img_pet[:, ::-1, idxes[3]].transpose(1, 0))
    mat_pet_5=adjust_size(img_pet[:, ::-1, idxes[4]].transpose(1, 0))
    mat_pet=np.c_[mat_pet_1, mat_pet_2, mat_pet_3, mat_pet_4, mat_pet_5]

    mat_t1w_outline_1=adjust_size(img_t1w_outline[:, ::-1, idxes[0]].transpose(1, 0), interp=0)
    mat_t1w_outline_2=adjust_size(img_t1w_outline[:, ::-1, idxes[1]].transpose(1, 0), interp=0)
    mat_t1w_outline_3=adjust_size(img_t1w_outline[:, ::-1, idxes[2]].transpose(1, 0), interp=0)
    mat_t1w_outline_4=adjust_size(img_t1w_outline[:, ::-1, idxes[3]].transpose(1, 0), interp=0)
    mat_t1w_outline_5=adjust_size(img_t1w_outline[:, ::-1, idxes[4]].transpose(1, 0), interp=0)
    mat_t1w_outline=np.c_[mat_t1w_outline_1, mat_t1w_outline_2, mat_t1w_outline_3, mat_t1w_outline_4, mat_t1w_outline_5]

    return mat_t1w, mat_pet, mat_t1w_outline

def get_mat_ref(img_ref, img_t1w_outline4pet, l, interp=1):
    idxes=get_display_indexes(img_t1w_outline4pet)
    mat_ref_1=adjust_size_pixdim(img_ref[:, ::-1, idxes[0]].transpose(1, 0), [l[1], l[0]])
    mat_ref_2=adjust_size_pixdim(img_ref[:, ::-1, idxes[1]].transpose(1, 0), [l[1], l[0]])
    mat_ref_3=adjust_size_pixdim(img_ref[:, ::-1, idxes[2]].transpose(1, 0), [l[1], l[0]])
    mat_ref_4=adjust_size_pixdim(img_ref[:, ::-1, idxes[3]].transpose(1, 0), [l[1], l[0]])
    mat_ref_5=adjust_size_pixdim(img_ref[:, ::-1, idxes[4]].transpose(1, 0), [l[1], l[0]])
    mat_ref=np.c_[mat_ref_1, mat_ref_2, mat_ref_3, mat_ref_4, mat_ref_5]

    mat_ref_outline_1=adjust_size_pixdim(img_t1w_outline4pet[:, ::-1, idxes[0]].transpose(1, 0), [l[1], l[0]], interp=0)
    mat_ref_outline_2=adjust_size_pixdim(img_t1w_outline4pet[:, ::-1, idxes[1]].transpose(1, 0), [l[1], l[0]], interp=0)
    mat_ref_outline_3=adjust_size_pixdim(img_t1w_outline4pet[:, ::-1, idxes[2]].transpose(1, 0), [l[1], l[0]], interp=0)
    mat_ref_outline_4=adjust_size_pixdim(img_t1w_outline4pet[:, ::-1, idxes[3]].transpose(1, 0), [l[1], l[0]], interp=0)
    mat_ref_outline_5=adjust_size_pixdim(img_t1w_outline4pet[:, ::-1, idxes[4]].transpose(1, 0), [l[1], l[0]], interp=0)
    mat_ref_outline=np.c_[mat_ref_outline_1, mat_ref_outline_2, mat_ref_outline_3, mat_ref_outline_4, mat_ref_outline_5]
    return mat_ref, mat_ref_outline, idxes

def get_qareport_process1(mat_t1w, mat_pet, mat_ref, mode='Mode1'):
    fig=plt.figure(figsize=(8.27, 11.69), dpi=300, facecolor='white')
    if mode=='Mode1':
        figtitle="QA Report (Overlay): Coregistration and Realignment"
        text1='Coregistered PET\non T1W'
    if mode=='Mode2':
        figtitle="QA Report (Outline): Coregistration and Realignment"
        text1='Coregistered\nPET'

    fig.text(0.5, 0.93, figtitle, size=18, ha='center', weight='bold')
    fig.text(0.5, 0.9, ID, size=14, ha='center', va='center')

    ax1=fig.add_axes((0.15, 0.75, 0.82, 0.14))
    fig.text(0.075, 0.82, text1, ha='center', va='center')
    
    if mode=='Mode1':
        ax1.imshow(mat_t1w, cmap='gray')
        msk=ax1.imshow(mat_pet, cmap='jet', alpha=0.4).set_clim(0.1, mat_pet.max())
    
    if mode=='Mode2':
        ax1.imshow(mat_pet, cmap='gray').set_clim(np.percentile(mat_pet, 1), np.percentile(mat_pet, 99))
        outline=np.zeros((mat_t1w.shape[0], mat_t1w.shape[1], 4))
        outline[:, :, 0]=1.0
        outline[:, :, 3]=mat_t1w
        #msk=ax1.imshow(outline)
        ax1.imshow(outline, interpolation='nearest').set_clim(0, 1)

    ax1.axes.xaxis.set_visible(False)
    ax1.axes.yaxis.set_visible(False)
    
    ax2=fig.add_axes((0.15, 0.61, 0.82, 0.14))
    fig.text(0.075, 0.68, 'Target image\nfor\nRealignment', ha='center', va='center')
    ax2.imshow(mat_ref, cmap='gray', aspect=l[1]/l[0]).set_clim(np.percentile(mat_ref, 1), np.percentile(mat_ref, 99))
    ax2.axes.xaxis.set_visible(False)
    ax2.axes.yaxis.set_visible(False)
    return fig

def get_mat_dyn(img_dyn, idxes, l, f_num):
    mat_dyn=adjust_size_pixdim(img_dyn[:, ::-1, idxes[0], f_num].transpose(1, 0), [l[1], l[0]])
    for i in range(1, 5):
        mat_dyn=np.c_[mat_dyn, adjust_size_pixdim(img_dyn[:, ::-1, idxes[i], f_num].transpose(1, 0), [l[1], l[0]])]
    return mat_dyn

def get_mat_dyn_multiple(img_dyn, idxes, l, start_num):
    mat_dyn_multiple=[get_mat_dyn(img_dyn, idxes, l, i) for i in range(start_num, start_num+4) if i<img_dyn.shape[3]]
    return mat_dyn_multiple

def get_qareport_process2(fig, mat_ref, mat_dyn_multiple, l, start_num, N_frame, mode='Mode1'):
    axs=[]
    for i, mat_dyn in enumerate(mat_dyn_multiple):
        axs.append(fig.add_axes((0.15, 0.47-0.14*i, 0.82, 0.14)))
        fig.text(0.075, 0.54-0.14*i, f'Realigned\nFrame\n{start_num+i+1} / {N_frame}', ha='center', va='center')
        if mode=='Mode1':
            axs[i].imshow(mat_ref, cmap='gray', aspect=l[1]/l[0]).set_clim(np.percentile(mat_ref, 1), np.percentile(mat_ref, 99))
            axs[i].imshow(mat_dyn, cmap='jet', aspect=l[1]/l[0], alpha=0.4).set_clim(0, mat_ref.max())
            footer='Each PET frame is overlaid on the target image.'
        if mode=='Mode2':
            axs[i].imshow(mat_dyn, cmap='gray', aspect=l[1]/l[0]).set_clim(np.percentile(mat_dyn, 1), np.percentile(mat_dyn, 99))
            matrix_outline=np.zeros((mat_ref.shape[0], mat_ref.shape[1], 4))
            matrix_outline[:, :, 0]=1.0
            matrix_outline[:, :, 3]=mat_ref
            axs[i].imshow(matrix_outline, aspect=l[1]/l[0], interpolation='nearest').set_clim(0, 1)
            footer='Red line: brain surface from T1W image.'

        axs[i].axes.xaxis.set_visible(False)
        axs[i].axes.yaxis.set_visible(False)

    fig.text(0.15, 0.04, footer)
        
    return fig

if __name__=="__main__":
    ID=sys.argv[1]
    t1w=sys.argv[2]
    pet_mean=sys.argv[3]
    pet_dyn=sys.argv[4]
    pet_ref=sys.argv[5]

    # Load Data
    img_t1w=nib.load(t1w).get_fdata()
    img_t1w_outline=nib.load(ID+'_t1w_brain_outline_r.nii').get_fdata()
    img_t1w_outline4pet=nib.load(ID+'_t1w_brain_outline4pet.nii').get_fdata()
    img_pet=nib.load(pet_mean).get_fdata()
    img_dyn=nib.load(pet_dyn).get_fdata()
    if len(img_dyn.shape)==3:
        img_dyn=img_dyn.reshape(list(img_dyn.shape)+[1])
    img_dyn=np.pad(img_dyn, pad_width=((1, 1), (1, 1), (1, 1), (0, 0)), mode='constant')
    img_ref=np.pad(nib.load(pet_ref).get_fdata(), pad_width=((1, 1), (1, 1), (1, 1)), mode='constant')

    # Determine FOV
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

    # Crop images within FOV
    img_ref=img_ref[max(int(Gx-size[0]/2), 0):min(int(Gx+size[0]/2), int(img_ref.shape[0]-1)),
                    max(int(Gy-size[1]/2), 0):min(int(Gy+size[1]/2), int(img_ref.shape[1]-1)),
                    max(int(Gz-size[2]/2), 0):min(int(Gz+size[2]/2), int(img_ref.shape[2]-1))]
    img_t1w_outline4pet=img_t1w_outline4pet[max(int(Gx-size[0]/2), 0):min(int(Gx+size[0]/2), int(img_t1w_outline4pet.shape[0]-1)),
                    max(int(Gy-size[1]/2), 0):min(int(Gy+size[1]/2), int(img_t1w_outline4pet.shape[1]-1)),
                    max(int(Gz-size[2]/2), 0):min(int(Gz+size[2]/2), int(img_t1w_outline4pet.shape[2]-1))]
    img_dyn=img_dyn[max(int(Gx-size[0]/2), 0):min(int(Gx+size[0]/2), int(img_dyn.shape[0]-1)),
                    max(int(Gy-size[1]/2), 0):min(int(Gy+size[1]/2), int(img_dyn.shape[1]-1)),
                    max(int(Gz-size[2]/2), 0):min(int(Gz+size[2]/2), int(img_dyn.shape[2]-1)), :]

    # Image to Matrix
    mat_t1w, mat_pet, mat_t1w_outline=get_mat_t1w_pet(img_t1w, img_pet, img_t1w_outline)
    mat_ref, mat_ref_outline, idxes=get_mat_ref(img_ref, img_t1w_outline4pet, l)

    # Create Summary
    for i in range((img_dyn.shape[3]-1)//4+1):
        # QA Report
        fig1=get_qareport_process1(mat_t1w, mat_pet, mat_ref)
        mat_dyn_multiple=get_mat_dyn_multiple(img_dyn, idxes, l, 4*i)
        fig2=get_qareport_process2(fig1, mat_ref, mat_dyn_multiple, l, 4*i, img_dyn.shape[3])
        fig2.savefig(f'{ID}_qareport_{i+1}.png')
        fig1.clear()
        fig2.clear()
        plt.close(fig1)
        plt.close(fig2)

        # QA Report (outline)
        fig1=get_qareport_process1(mat_t1w_outline, mat_pet, mat_ref, mode='Mode2')
        fig2=get_qareport_process2(fig1, mat_ref_outline, mat_dyn_multiple, l, 4*i, img_dyn.shape[3], mode='Mode2')
        fig2.savefig(f'{ID}_qaoutline_{i+1}.png')
        fig1.clear()
        fig2.clear()
        plt.close(fig1)
        plt.close(fig2)

    exit()

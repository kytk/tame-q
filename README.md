# README

## Background
Semi-Quantification is crucial for analyzing PET images. This process often involves multiple complex steps and tools. THAME-Q aims to streamline these processes into a single, efficient workflow.

## Overview
- This project aims to calculate SUVR images and SUVR values for each region from PMPBB3 PET data.
- The project consists of the following scripts:

    1. Alignment of T1-weighted and PMPBB3 PET images
    2. Gray and White Matter Segmentation (using Statistical Prametric Mapping 12)
    3. Determination of reference values using the histogram method and generation of SUVR images
    4. Subcortical segmentation and cortical parcellation of MRI data (using FreeSurfer)
    5. Determination of reference values using signals in cerebeller cortex
    6. Calculation of SUVR values for each region and creation of summary tables

## System Requirements
- The following software and libraries must be installed: Python 3 (with Nibabel, Scipy, Matplotlib, and Numpy), FSL (version 6.0.5.2 or later), FreeSurfer (version 7.3.2 or later), and SPM (preferably standalone version).
- The recommended setup involves running Lin4Neuro on VirtualBox, but the scripts can also run on individual environments where the above software is installed. In such cases, please ensure to appropriately modify the path of config.env to match your environment.

## Recommended Environment Setup
- Install VirtualBox and download Lin4Neuro 22.04 from [nemotos.net](https://www.nemotos.net/?page_id=29). Refer to nemotos.net for detailed instructions about L4N installation.
- Once Lin4Neuro is imported, launch a terminal and run the following commands:

    ```bash
    # Clone the THAME-Q repository
    cd ~/git
    git clone https:github.com/kytk/thameq.git

    # Update installer scripts
    cd ~/git/lin4neuro-jammy
    git pull

    # Install FreeSurfer
    ~/git/lin4neuro-jammy/installer-scripts/freesurfer7.4.1_installer.sh
    
    # Install tcsh
    sudo apt-get install tcsh
    ```

## Preparing for THAME-Q Execution
- THAME-Q identifies the image pairs to process based on file naming conventions. Rename the files you wish to process according to the following rules:
    - T1-weighted image: `ID_t1w.nii.gz`
    - PET image: `ID_pmpbb3_dyn.nii.gz`
  Here, `ID` can be any unique string that identifies the image pair, but the first character must be uppercase.
    - Example: If the `ID` is `CON_001`:
        - T1-weighted image: `CON_001_t1w.nii.gz`
        - PET image: `CON_001_pmpbb3_dyn.nii.gz`
  As THAME-Q is primarily developed for analyzing PM-PBB3 PET data, the filename suffix is currently fixed as `pmpbb3_dyn`. Even for images acquired using other tracers, this naming convention should be followed. However, plans are in place to make filename recognition more flexible in the future.

## Running THAME-Q
- Navigate to the directory containing the prepared files and run the following command:

    ```bash
    tq-all.sh
    ```

- A list of recognized images will be displayed. If the list is correct, type `y`. This will initiate preprocessing, semi-quantification, and table generation for the processed data.

## License
This project is licensed under the GNU General Public License v3.0. See the LICENSE file for details.

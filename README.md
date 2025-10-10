# README

## Background
Semi-quantification is crucial for analyzing PET images. This process often involves multiple complex steps and tools. TAME-Q aims to streamline these steps into a single, efficient workflow.

## Overview
<img width="8000" height="4500" alt="Image" src="https://github.com/user-attachments/assets/28b01865-35a0-4ebe-b7d3-0b54ed76d113" />

- This project aims to generate SUVR images and calculate SUVR values for each region from PM-PBB3 PET data.
- The project consists of the following scripts:

    1. Alignment of T1-weighted and PM-PBB3 PET images
    2. Gray and White Matter Segmentation (using Statistical Parametric Mapping 12)
    3. Determination of reference values using the histogram method and generation of SUVR images
    4. Subcortical segmentation and cortical parcellation of MRI data (using FreeSurfer)
    5. Determination of reference values using signals in the cerebellar cortex
    6. Calculation of SUVR values for each region and creation of summary tables

## System Requirements
- The following software and libraries must be installed:
  - FSL (version 6.0.5.2 or later)
  - FreeSurfer (version 7.4.1)
  - Python 3 (with Nibabel, Scipy, Matplotlib, and Numpy)
  - SPM (preferably standalone version)
- If you want to run TAME-Q scripts in your own environment, make sure to modify the path in config.env appropriately.
- A preconfigured virtual environment for TAME-Q is publicly available, provided by Lin4Neuro (Ubuntu 22.04) on Docker and VirtualBox. You do not need to install the above dependencies if you use this environment (see the next section).

## TAME-Q Virtual Environments
To run **TAME-Q**, we provide an optimized virtual environment based on **Lin4Neuro (Ubuntu 22.04)**.  
It is distributed in two formats:
1. **Docker container**
2. **OVA file** for use with VirtualBox  

### Common Setup Steps
- On your host machine, create a folder named **`share`**.  
  This will be configured later as the shared folder between the host and the virtual environment.  
- TAME-Q requires a **FreeSurfer** license.
  Please place your FreeSurfer license file (**`license.txt`**) directly under the **`share`** folder.

### (1) Docker Container
1. Complete the common setup steps.
2. From a terminal (Linux/macOS) or PowerShell (Windows), move to the **`share`** folder.
3. (a) If you prefer a CLI virtual environment, run the following command to start the container:
   ```bash
   docker run -it --rm -e MODE=bash -v .:/home/brain/share tame-q:latest
   ```

   (b) If you prefer a GUI virtual environment, run the following command:
   ```bash
   docker run -d -p 6080:6080 -v .:/home/brain/share tame-q:latest
   ```
   Once the container is running, open your web browser and go to http://localhost:6080/vnc.html (login: **brain**, password: **lin4neuro**)
   In the Docker version of L4N, the **`share`** folder configured on the host machine is mounted as /home/brain/share inside the container.

### (2) OVA File for VirtualBox
1. Complete the common setup steps.
2. Install **VirtualBox**.
3. Download the OVA file from [the link](https://www.dropbox.com/t/M1QYlvykHu6lPAyF) (MD5 sum: `8f3a60167843fa7d29ac630bb2351e4b`).
4. Import the OVA file into VirtualBox.
5. After importing Lin4Neuro, adjust the **memory size** and **number of processors** according to your system resources.  
6. For general usage of Lin4Neuro, please refer to [nemotos.net](http://nemotos.net).
7. Boot "L4N-2204-TAME-Q" virtual environment (login: **brain**, password: **lin4neuro**).
8. Open a terminal and run the following command to copy the license file to the correct location:
   ```bash
   cp -n /media/sf_share/license.txt $FS_LICENSE

## Preparing for TAME-Q Execution
- TAME-Q accepts NIfTI images as input. If you would like to apply TAME-Q to DICOM images, we recommend converting them with [dcm2niix](https://github.com/rordenlab/dcm2niix). Please note that images converted using other methods have not been validated for compatibility. For details on how to use dcm2niix, please refer to the official documentation.
- TAME-Q identifies the image pairs to process based on file naming conventions. Rename the files you wish to process according to the following rules:
    - T1-weighted image: `ID_t1w.nii.gz`
    - PET image: `ID_pmpbb3_dyn.nii.gz`
  Here, `ID` can be any unique string that identifies the image pair, but **the first character must be uppercase**.
    - Example: If the `ID` is `CON_001`:
        - T1-weighted image: `CON_001_t1w.nii.gz`
        - PET image: `CON_001_pmpbb3_dyn.nii.gz`
  Since TAME-Q was developed primarily for PM-PBB3 PET data, the filename suffix is currently fixed as `pmpbb3_dyn`. Even for images acquired using other tracers, this naming convention should be followed. We plan to make filename recognition more flexible in the future.

## Running TAME-Q
- Navigate to the directory containing the prepared files and run the following command:
    ```bash
    tq-all.sh
    ```
- A list of recognized images will be displayed. If the list is correct, type `y`. This will initiate preprocessing, semi-quantification, and table generation for the processed data.
- Example: Assume that your data is stored in the share folder as follows:
    ```
    share
    ├── data
    │   ├── ID001_pmpbb3_dyn.nii.gz
    │   ├── ID001_t1w.nii.gz
    │   ├── ID002_pmpbb3_dyn.nii.gz
    │   ├── ID002_t1w.nii.gz
    │   ├── ID003_pmpbb3_dyn.nii.gz
    │   └── ID003_t1w.nii.gz
    └── license.txt
    ```
    You can run TAME-Q as follows:
    ```bash
    cd /home/brain/share/data
    tq-all.sh
    ```
- Sample data for testing is available at /home/brain/Sample in our virtual environment. You can run the following to test with the sample data:
    ```bash
    cd /home/brain/Sample
    tq-all.sh
    ```

## License
This project is licensed under the GNU General Public License v3.0. See the LICENSE file for details.

## Citation
Nakayama K, Nemoto K, Endo H, et al. TAME-Q: An open-source preprocessing pipeline for reproducible semi-quantification of florzolotau (18F) PET. medRxiv. Published online October 9, 2025:2025.10.08.25337562. doi:10.1101/2025.10.08.25337562  


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
- A preconfigured virtual environment for TAME-Q is publicly available, provided by Lin4Neuro (based on Ubuntu 22.04) on Docker. This virtual environment satisfies the below dependencies:
  - FSL (version 6.0.5.2 or later)
  - FreeSurfer (version 7.4.1)
  - Python 3 (with Nibabel, Scipy, Matplotlib, and Numpy)
  - SPM (preferably standalone version)
- If you want to run TAME-Q scripts in your own environment, make sure to modify the path in config.env appropriately.

### Common Setup Steps
- On your host machine, create a folder named **`share`**.
  This will be configured later as the shared folder between the host and the virtual environment. 
  **Important:** If the host machine is running Windows OS and a shared folder is located on an external drive, the drive must be formatted with NTFS.
- TAME-Q requires a **FreeSurfer** license.
  Please place your FreeSurfer license file (**`license.txt`**) directly under the **`share`** folder.

### Docker Image
1. Complete the above common setup steps.
2. From a terminal (Linux/macOS) or PowerShell (Windows), move to the **`share`** folder.
3. Run the following command:
   ```bash
   docker run --platform linux/amd64 --shm-size 2g -d -p 6080:6080 -v .:/home/brain/share kytk/tame-q:latest
   ```
   Once the container is running, open your web browser and go to http://localhost:6080/vnc.html (password: **lin4neuro**)
   In the Docker version of L4N, the **`share`** folder configured on the host machine is mounted as /home/brain/share inside the container.

## Preparing for TAME-Q Execution
- TAME-Q accepts NIfTI images as input. If you would like to apply TAME-Q to DICOM images, we recommend converting them with [dcm2niix](https://github.com/rordenlab/dcm2niix). Please note that images converted using other methods have not been validated for compatibility. For details on how to use dcm2niix, please refer to the official documentation.

## Running TAME-Q
- The easiest way to run tame-q is with the following command:
    ```bash
    tq-all.sh --id <ID> --mri <MRI file> --pet <PET file> [--outdir path (optional)] [options]
    ```
- Example: Suppose your data are stored in the `share` directory as follows:
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
    You can run TAME-Q for subject `ID001` as follows:
    ```bash
    cd /home/brain/share/data
    mkdir result    # Prepare a directory for tame-q results
    tq-all.sh --id ID001 --mri ID001_t1w.nii.gz --pet ID001_pmpbb3_dyn.nii.gz --outdir result
    ```
- To process multiple subjects in a batch, place the following files in a single directory:
    1. A T1-weighted MRI NIfTI file with the suffix `t1w`.
    2. A PET NIfTI file with the same subject ID but a different suffix (for example, if the PET suffix is `_pet`, the file should be named `ID_pet.nii.gz`).
    Then run the following command inside that directory:
    ```bash
    tq-all.sh --parallel <number>
    ```
    Files matching the naming rule will be automatically detected. (Subjects will be skipped if multiple PET files match the same ID.) A list of detected files will be displayed. If the list is correct, type y to start batch processing.

- Sample data for testing is available at /home/brain/Sample in our virtual environment. You can run the following to test with the sample data:
    ```bash
    cd /home/brain/Sample
    tq-all.sh --id Sample001 --mri Sample001_t1w.nii.gz --pet Sample001_pmpbb3_dyn.nii.gz --outdir 
    ```

## License
This project is licensed under the GNU General Public License v3.0. See the LICENSE file for details.

## Citation
Nakayama K, Nemoto K, Endo H, et al. TAME-Q: An open-source preprocessing pipeline for reproducible semi-quantification of florzolotau (18F) PET. medRxiv. Published online October 9, 2025:2025.10.08.25337562. doi:10.1101/2025.10.08.25337562  
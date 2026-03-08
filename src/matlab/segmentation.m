%% segmentation.m
% Template script for preprocessing of t1w image in tame-q
% 8 Mar 2026 K.Nakayama and K.Nemoto

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Please replace the below MR_IMAGE_PATH
% with your file you want to do segmentation
% (Be careful not to erase the suffix ',1')
% Example:
%    A t1w image is saved as /home/user/data/t1w.nii, then:
%    img='/home/user/data/t1w.nii,1'

img='MR_IMAGE_PATH,1';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Select Image files
% please change the filter
t1vols = cellstr(img);

%% Step 1
%% Initialize batch
spm_jobman('initcfg');
matlabbatch = {};

display('Segmentation');
%% Segmentation
matlabbatch{1}.spm.spatial.preproc.channel.vols = t1vols;
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 0];
ngaus  = [1 1 2 3 4 2];
native = [1 1 0 0 0 0
          0 0 0 0 0 0];
for c = 1:6 % tissue class c
    matlabbatch{1}.spm.spatial.preproc.tissue(c).tpm = {
        fullfile(spm('dir'), 'tpm', sprintf('TPM.nii,%d', c))};
    matlabbatch{1}.spm.spatial.preproc.tissue(c).ngaus = ngaus(c);
    matlabbatch{1}.spm.spatial.preproc.tissue(c).native = native(:, c)';
    matlabbatch{1}.spm.spatial.preproc.tissue(c).warped = [0 0];
end

matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 0];
matlabbatch{1}.spm.spatial.preproc.warp.vox = NaN;
matlabbatch{1}.spm.spatial.preproc.warp.bb = [NaN NaN NaN
                                              NaN NaN NaN];


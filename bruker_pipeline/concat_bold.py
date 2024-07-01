import numpy as np
import nibabel as nib
import argparse
import os
import re

def replace_run_x(text):
    pattern = r'run-.*?_'
    return re.sub(pattern, '', text)

def cat_nifti(files):
    img1 = nib.load(files[0])
    nii_data_1 = img1.get_fdata()
    full_data = nii_data_1
    affine = img1.affine
    header = img1.header

    for file in files[1:]:
        img = nib.load(file)
        nii_data = img.get_fdata()
        full_data = np.concatenate((full_data, nii_data), axis=-1)
        header['dim'][3] += nii_data.shape[-1]

    new_image = nib.Nifti1Image(full_data, affine=affine, header=header)

    for file in files:
        os.remove(file)

    new_path = replace_run_x(files[0])
    nib.save(new_image, new_path)


def delete_json_files(func_dir):
    json_files = [os.path.join(func_dir, f) for f in os.listdir(func_dir) if f.endswith('.json')]
    for json_file in json_files:
        os.remove(json_file)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Concatenate NIfTI files in a BIDS directory')
    parser.add_argument('main_directory', type=str, help='Path to the main BIDS directory')

    args = parser.parse_args()
    main_directory = args.main_directory

    for subject in os.listdir(main_directory):
        subject_dir = os.path.join(main_directory, subject)
        
        if os.path.isdir(subject_dir):
            func_dir = os.path.join(subject_dir, 'func')
            nifti_files = [os.path.join(func_dir, f) for f in os.listdir(func_dir) if f.endswith('.nii.gz')]
            
            if len(nifti_files) > 1:
                print(f"Concatenating {len(nifti_files)} files in {func_dir}")
                cat_nifti(nifti_files)
                delete_json_files(func_dir)
            else:
                print(f"Skipping {func_dir} as it contains {len(nifti_files)} file(s)")

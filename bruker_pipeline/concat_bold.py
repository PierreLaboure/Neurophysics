import numpy as np
import nibabel as nib
import argparse
import os 

def cat_nifti(path1, path2):

    img1  = nib.load(path1)
    nii_data_1 = img1.get_fdata()
    dim1 = nii_data_1.shape[-1]

    img2  = nib.load(path2)
    nii_data_2 = img2.get_fdata()
    dim2 = nii_data_2.shape[-1]
    print("Nifit shapes", nii_data_1.shape, nii_data_2.shape)

    new_header = img1.header
    new_header['dim'][3] = dim1+dim2

    full_data = np.concatenate((nii_data_1, nii_data_2), axis =-1)

    new_image = nib.Nifti1Image(full_data, affine=img1.affine, header=new_header)
    new_path = path1.replace('run-01_', '').replace('run-02_', '')
    nib.save(new_image, new_path)


    os.remove(path1)
    os.remove(path2)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Optional app description')

    parser.add_argument('main_directory', type=str,
                        help='name of the bids directory')

    args = parser.parse_args()
    main_directory = args.main_directory

    for f in os.listdir(main_directory):
        print("processing " + f)
        if os.path.isdir(os.path.join(main_directory, f)):

            func_dir = os.path.join(main_directory, f, 'func')
            run_01 = os.path.join(func_dir, [f for f in os.listdir(func_dir) if f.endswith('.nii.gz')][0])
            run_02 = os.path.join(func_dir, [f for f in os.listdir(func_dir) if f.endswith('.nii.gz')][1])

            cat_nifti(run_01, run_02)

            json1 = os.path.join(func_dir, [f for f in os.listdir(func_dir) if f.endswith('.json')][0])
            json2 = os.path.join(func_dir, [f for f in os.listdir(func_dir) if f.endswith('.json')][1])
            os.remove(json1)
            os.remove(json2)
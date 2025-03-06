import nibabel as nib
import numpy as np

import argparse
import os
import glob
import pickle

def main(args=None):

    parser = argparse.ArgumentParser(description='Process some parameters.')

    parser.add_argument('-i', type=str, required= True,
                        help='Path to input image to crop')
    parser.add_argument('-r', type=str, required = True,
                        help='Path to an image rigidely registered to input image')
    parser.add_argument('--inplace', type=int,
                        help='1 to overwrite when cropping, 0 to create a croped copy called crop.nii.gz')
    
    # Parsing arguments
    args = parser.parse_args(args)
    img_path = args.i
    r_path = args.r
    inplace=args.inplace

    print(f'Cropping {img_path} using {r_path}')

    img = nib.load(r_path)
    warped = img.get_fdata()

    img = nib.load(img_path)
    img2crop_aff = img.affine
    img2crop_hdr = img.header
    img2crop = img.get_fdata()

    mask = warped!=0
    new_img2crop = nib.Nifti1Image(np.where(mask, img2crop, 0), img2crop_aff, img2crop_hdr)
    if inplace:
        new_img2crop_path = img_path
    else:
        new_img2crop_path = os.path.join(os.path.dirname(img_path), 'crop.nii.gz')
    nib.save(new_img2crop, new_img2crop_path)


if __name__ == "__main__":
    main()

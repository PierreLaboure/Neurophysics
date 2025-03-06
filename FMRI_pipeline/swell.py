import nibabel as nib
import numpy as np

import argparse
import os
import glob
import pickle


def main(args=None):

    parser = argparse.ArgumentParser(description='Swell, transpose and crop images or deflate and transpose them.')

    parser.add_argument('-i', '--input', type=str, required= True,
                        help='Path to input image')
    parser.add_argument('-s', '--swell', type=float, required=True,
                        help = 'swell factor. Use a swell factor >1 even when performing deflation')
    parser.add_argument('--inverse', type=int, default=0,
                        help='1 to perform deflation')
    parser.add_argument('--crop', type=int, default=0,
                        help='1 to crop images to have even voxel on each axis')

    args = parser.parse_args(args)
    input_path = args.input
    swell = args.swell
    inverse = args.inverse
    crop = args.crop

    img=nib.load(input_path)
    data = img.get_fdata()
    shp = data.shape

    if crop:
        data = data[shp[0]%2:, shp[1]%2:, shp[2]%2:]
    if len(data.shape)==4:
        if not inverse:
            new_img = nib.Nifti1Image(np.transpose(data, (0,2,1,3))[::-1], img.affine[:, [0, 2, 1, 3]]*swell, img.header)
            nib.save(new_img, input_path.replace('.nii.gz', '_SwellT.nii.gz'))
        if inverse:
            new_img = nib.Nifti1Image(np.transpose(data, (0,2,1,3))[::-1], img.affine[:, [0, 2, 1, 3]]/swell, img.header)
            if 'SwellT' in input_path:
                new_name = input_path.replace('SwellT', 'UnSwellT')
            else:
                new_name = input_path.replace('.nii.gz', '_UnSwellT.nii.gz')
            nib.save(new_img, new_name)
    else:
        if not inverse:
            new_img = nib.Nifti1Image(np.transpose(data, (0,2,1))[::-1], img.affine[:, [0, 2, 1, 3]]*swell, img.header)
            nib.save(new_img, input_path.replace('.nii.gz', '_SwellT.nii.gz'))
        if inverse:
            new_img = nib.Nifti1Image(np.transpose(data, (0,2,1))[::-1], img.affine[:, [0, 2, 1, 3]]/swell, img.header)
            if 'SwellT' in input_path:
                new_name = input_path.replace('SwellT', 'UnSwellT')
            else:
                new_name = input_path.replace('.nii.gz', '_UnSwellT.nii.gz')
            nib.save(new_img, new_name)



if __name__ == "__main__":
    main()
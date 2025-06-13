import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import argparse
import os
import glob
import pickle

from aggregate_utils import aggregate_ROI, ROI_FC, str2bool

def main(args=None):

    parser = argparse.ArgumentParser(description='Process some parameters.')

    parser.add_argument('atlas_path', type=str,
                        help='Path to an Atlas in nifti format')
    parser.add_argument('common_mask', type=str,
                        help='Path to melodic mask to prevent using ROIs outside of bold scans')
    parser.add_argument('ROI_path', type=str,
                        help='Path to ROI xlsx file containing the desired ROIs')
    parser.add_argument('--output_path', type=str,
                        help='Path to output directory')
    parser.add_argument('--agg_LR', type=str2bool, nargs='?', const=True, default=False,
                        help='True if you want to aggregate Right and Left Hemispheres')

    args = parser.parse_args(args)
    ROI_path = args.ROI_path
    atlas_path = args.atlas_path
    output_path = args.output_path
    agg_LR = args.agg_LR
    common_mask_path = args.common_mask

    nii_common_mask = nib.load(common_mask_path)
    common_mask = nii_common_mask.get_fdata()

    # Loading the Atlas from nifti
    my_img  = nib.load(atlas_path)
    atlas_data = my_img.get_fdata()

    agg_ROI_labels = aggregate_ROI(ROI_path, agg_LR)

    atlas_data = np.where(common_mask, atlas_data, 0)

    counts = {region: np.sum(np.isin(atlas_data, labels))
          for region, labels in agg_ROI_labels.items()}
    
    print(counts)


if __name__ == "__main__":
    main()
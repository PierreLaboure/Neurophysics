import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import argparse
import os
import glob

from aggregate_utils import aggregate_ROI, ROI_FC

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Process some parameters.')

    parser.add_argument('--ROI_path', type=str,
                        help='')
    parser.add_argument('--atlas_path', type=str,
                        help='')
    parser.add_argument('--confound_path', type=str,
                        help='')
    parser.add_argument('--output_path', type=str,
                        help='')
    parser.add_argument('--agg_LR', type=bool,
                        help='')
    
    args = parser.parse_args()

    ROI_path = args.ROI_path
    atlas_path = args.atlas_path
    confound_path = args.confound_path
    output_path = args.output_path
    agg_LR = args.agg_LR
    

    #atlas_path = 'DSURQE_40micron_labels.nii'
    my_img  = nib.load(atlas_path)
    atlas_data = my_img.get_fdata()

    #creating directories to store Correlation Matrices and Figures
    FC_data_dir = os.path.join(output_path, "FC_matrix_data")
    FC_figures_dir = os.path.join(output_path, "FC_matrix_fig")
    os.makedirs(output_path, exist_ok=True)
    os.makedirs(FC_data_dir, exist_ok=True)
    os.makedirs(FC_figures_dir, exist_ok=True)

    agg_ROI_labels = aggregate_ROI(ROI_path, agg_LR)


    # Base directory
    base_dir = os.path.join(confound_path, 'confound_correction_datasink/cleaned_timeseries')


    # Traverse the directory structure
    for root, dirs, files in os.walk(base_dir):
        for dir_name in dirs:
            print('processing ' + dir_name)
            # Check if the directory name matches the pattern "_split_name_image_name"
            if dir_name.startswith('_split_name_'):
                # Extract the "image_name" part from the directory name
                image_name = dir_name[len('_split_name_'):]
                # Construct the full path to the directory
                dir_path = os.path.join(root, dir_name)
                # Get the list of files in the directory
                file_list = glob.glob(os.path.join(dir_path, '*'))
                # Assuming each directory contains exactly one file
                if len(file_list) == 1:
                    matrix_name = os.path.join(FC_data_dir, image_name) + "_FC_matrix_data.npy"
                    fig_name = os.path.join(FC_figures_dir, image_name) + "_FC_matrix_fig.png"
                    confound_image_path = file_list[0]

                    ROI_FC(agg_ROI_labels, atlas_data, confound_image_path, fig_name, matrix_name)


        
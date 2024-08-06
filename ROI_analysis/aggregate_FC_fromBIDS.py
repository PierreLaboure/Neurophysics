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

    parser.add_argument('--ROI_path', type=str,
                        help='Path to ROI xlsx file containing the desired ROIs')
    parser.add_argument('--BIDS_path', type=str,
                        help='Path to a BIDS structure with preprocess and confound correction inside')
    parser.add_argument('--output_path', type=str,
                        help='Path to output directory')
    parser.add_argument('--agg_LR', type=str2bool, nargs='?', const=True, default=False,
                        help='True if you want to aggregate Right and Left Hemispheres')
    parser.add_argument('--sub_list', type=str,
                        help='List of subjects to analyse')
    
    # Parsing arguments
    args = parser.parse_args(args)
    ROI_path = args.ROI_path
    BIDS_path = args.BIDS_path
    output_path = args.output_path
    agg_LR = args.agg_LR
    sub_list = args.sub_list

    # Checking if a subset of Subject has been parsed
    subsetSub = (sub_list is not None)
    if subsetSub:
        subject_list = []
        with open(sub_list, "r") as f:
            lines = f.readlines()
            for line in lines:
                subject_list.append(line.strip())
                
    #Retrieving atlas undersampled from preprocess dir
    labels_dir = os.path.join(BIDS_path, 'preprocess/bold_datasink/commonspace_labels')
    for i, (root, dirs, files) in enumerate(os.walk(labels_dir)):
        if i>=2:
            break
    atlas_path = os.path.join(root, files[0])

    # Loading the Atlas from nifti
    my_img  = nib.load(atlas_path)
    atlas_data = my_img.get_fdata()

    #creating directories to store Correlation Matrices and Figures
    FC_data_dir = os.path.join(output_path, "FC_matrix_data")
    FC_figures_dir = os.path.join(output_path, "FC_matrix_fig")
    parameter_file = os.path.join(output_path, "parameters.pkl")
    os.makedirs(output_path, exist_ok=True)
    os.makedirs(FC_data_dir, exist_ok=True)
    os.makedirs(FC_figures_dir, exist_ok=True)


    # Creating parameters to be saved for later functions
    parameters = {}

    agg_ROI_labels = aggregate_ROI(ROI_path, agg_LR)

    ROI_names = list(agg_ROI_labels.keys())
    parameters["ROI_names"] = ROI_names
    parameters["agg_LR"] = agg_LR
    parameters["BIDS_path"] = BIDS_path
    parameters["ROI_path"] = ROI_path
    parameters["atlas_path"] = atlas_path
    if subsetSub:
        parameters["subject_list"] = subject_list

    with open(parameter_file, "wb") as fp:   #Pickling
        pickle.dump(parameters, fp)

    ## looping through confound files
    timeseries_dir = os.path.join(BIDS_path, 'confound/confound_correction_datasink/cleaned_timeseries')

    # Traverse the directory structure
    for root, dirs, files in os.walk(timeseries_dir):
        for dir_name in dirs:
            # Check if the directory name matches the pattern "_split_name_image_name"
            if dir_name.startswith('_split_name_'):
                # Extract the "image_name" part from the directory name
                image_name = dir_name[len('_split_name_'):]
                # Construct the full path to the directory
                dir_path = os.path.join(root, dir_name)
                # Get the list of files in the directory
                file_list = glob.glob(os.path.join(dir_path, '*'))
                if subsetSub:
                    subject_name = os.path.basename(file_list[0])
                    if subject_name not in subject_list:
                        continue
                # Assuming each directory contains exactly one file
                if len(file_list) == 1:
                    print('processing ' + dir_name)
                    matrix_name = os.path.join(FC_data_dir, image_name) + "_FC_matrix_data.npy"
                    fig_name = os.path.join(FC_figures_dir, image_name) + "_FC_matrix_fig.png"
                    confound_image_path = file_list[0]
                    
                    ROI_FC(agg_ROI_labels, atlas_data, confound_image_path, fig_name, matrix_name)


if __name__ == "__main__":
    main()
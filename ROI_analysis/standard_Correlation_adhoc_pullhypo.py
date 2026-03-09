import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import argparse
import os
import glob
import pickle

from aggregate_utils import compute_correlation, str2bool, get_label2roi, fillNa_labels2roi, undersample

def main(args=None):

    parser = argparse.ArgumentParser(description='Process some parameters.')

    parser.add_argument('--mode', type=str,
                        help="'R' for Pearson's R correlation, 'ICOV' for inverse correlation")
    parser.add_argument('--atlas_path', type=str,
                        help='Path to an Atlas in nifti format')
    parser.add_argument('--confound_path', type=str,
                        help='Path to a confound directory obtained from RABIES')
    parser.add_argument('--output_path', type=str,
                        help='Path to output directory')
    parser.add_argument('--common_mask', type=str,
                        help='Path to melodic mask to prevent using ROIs outside of bold scans')
    parser.add_argument('--sub_list', type=str,
                        help='List of subjects to analyse')
    
    
    # Parsing arguments
    args = parser.parse_args(args)
    ROI_path = '/volatile/home/pl279327/Documents/ATLAS/atlas_data/ROI_HAMBURGERS.xlsx'
    ROI_ABSID_path = '/volatile/home/pl279327/Documents/ATLAS/atlas_data/NEW_ORDER_adhoc_pullHypo/ATLAS_ID_ORDER.pkl'
    ABSID_ROI_path = '/volatile/home/pl279327/Documents/ATLAS/atlas_data/NEW_ORDER_adhoc_pullHypo/ID_ATLAS_ORDER.pkl'

    mode = args.mode
    atlas_path = args.atlas_path
    confound_path = args.confound_path
    output_path = args.output_path
    common_mask_path = args.common_mask
    sub_list = args.sub_list


    # Loading ROI XL file
    ROI = pd.read_excel(ROI_path)
    # Loading Absolute ID to label dictionnary
    with open(ROI_ABSID_path, 'rb') as f:
        ROI_ABSID = pickle.load(f)
    with open(ABSID_ROI_path, 'rb') as f:
        ABSID_ROI = pickle.load(f)
    with open('/volatile/home/pl279327/Documents/ATLAS/atlas_data/NEW_ORDER_adhoc_pullHypo/XL2pullhypo.pkl', 'rb') as f:
        XL2pullhypo = pickle.load(f)
    with open('/volatile/home/pl279327/Documents/ATLAS/atlas_data/NEW_ORDER_adhoc_pullHypo/pullhypo2XL.pkl', 'rb') as f:
        pullhypo2XL = pickle.load(f)
    with open('/volatile/home/pl279327/Documents/ATLAS/atlas_data/NEW_ORDER_adhoc_pullHypo/base2pullhypo.pkl', 'rb') as f:
        base2pullhypo = pickle.load(f)
    # Loading the Atlas from nifti and instantly flatten it
    my_img  = nib.load(atlas_path)
    labels_map = my_img.get_fdata()


    # mask labels map with common mask
    if (common_mask_path is not None):
        nii_common_mask = nib.load(common_mask_path)
        common_mask = nii_common_mask.get_fdata()
        if labels_map.shape != common_mask.shape:
            labels_map = undersample(labels_map, common_mask.shape)
        labels_map = np.where(common_mask, labels_map, np.nan)


    labels_map = labels_map.reshape(-1)
    abs_labels_map = np.copy(labels_map)


    labels2roi = ABSID_ROI
    for roi, absid in ROI_ABSID.items():
        row = ROI[ROI['Structure']==roi]
        if not row.empty:
            right_label, left_label = row['right label'].values[0], row['left label'].values[0]
            abs_labels_map[np.isin(labels_map, [right_label, left_label])] = absid
        else:
            XL_entry = pullhypo2XL[absid]
            print(XL_entry, absid)
            abs_labels_map[np.isin(labels_map, [XL_entry])] = absid
    labels_map = abs_labels_map     

    # fill the labels2roi dictionnary with None values where ids do not match a ROI and return the size of the correlation matrices
    labels2roi, N = fillNa_labels2roi(labels2roi)
    ROI_names = list(labels2roi.values())



    # Checking if a subset of Subject has been parsed
    subsetSub = (sub_list is not None)
    if subsetSub:
        subject_list = []
        with open(sub_list, "r") as f:
            lines = f.readlines()
            for line in lines:
                subject_list.append(line.strip())


    # Creating parameters to be saved for later functions
    parameters = {}
    parameters['mode'] = mode
    parameters["atlas_path"] = atlas_path
    parameters["ROI_names"] = ROI_names
    parameters["labels2roi"] = labels2roi
    parameters["confound_path"] = confound_path
    parameters["ROI_path"] = ROI_path


    #creating directories to store Correlation Matrices and Figures
    FC_data_dir = os.path.join(output_path, "FC_matrix_data")
    FC_figures_dir = os.path.join(output_path, "FC_matrix_fig")
    parameter_file = os.path.join(output_path, "parameters.pkl")
    os.makedirs(output_path, exist_ok=True)
    os.makedirs(FC_data_dir, exist_ok=True)
    os.makedirs(FC_figures_dir, exist_ok=True)



    if subsetSub:
        parameters["subject_list"] = subject_list
        for confound_file in subject_list:
            print('processing ' + confound_file)
            image_name = os.path.basename(confound_file).split('.nii.gz')[0] + '_bold'
            matrix_name = os.path.join(FC_data_dir, image_name) + "_FC_matrix_data.npy"
            fig_name = os.path.join(FC_figures_dir, image_name) + "_FC_matrix_fig.png"
            compute_correlation(mode, labels2roi, confound_file, N, labels_map, fig_name, matrix_name)


    else:
        ## looping through confound files
        # Base directory
        base_dir = os.path.join(confound_path, 'confound_correction_datasink/cleaned_timeseries')
        # Traverse the directory structure
        for root, dirs, files in os.walk(base_dir):
            for dir_name in dirs:
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
                        print('processing ' + dir_name)
                        matrix_name = os.path.join(FC_data_dir, image_name) + "_FC_matrix_data.npy"
                        fig_name = os.path.join(FC_figures_dir, image_name) + "_FC_matrix_fig.png"
                        confound_image_path = file_list[0]
                        compute_correlation(mode, labels2roi, confound_image_path, N, labels_map, fig_name, matrix_name)


    with open(parameter_file, "wb") as fp:   #Pickling
        pickle.dump(parameters, fp)

if __name__ == "__main__":
    main()
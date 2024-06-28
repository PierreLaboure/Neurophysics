import numpy as np
import matplotlib.pyplot as plt

from mne_connectivity.viz import plot_connectivity_circle

import os 
import glob
import pickle
import argparse

from aggregate_utils import node_angle

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process some parameters.')

    parser.add_argument('output_path', type=str,
                            help='Path to output directory')
    
    parser.add_argument('--matrix_list', type=str,
                            help='list of matrices of subject')
    
    # Parsing arguments
    args = parser.parse_args()
    output_path = args.output_path
    matrix_list = args.matrix_list

    # Extracting parameters
    parameters_file = os.path.join(output_path, "parameters.pkl")
    with open(parameters_file, "rb") as fp:   #Pickling
        parameters = pickle.load(fp)

    # Checking and exploiting a potential list of matrices
    subsetSub = (matrix_list is not None)
    if subsetSub:
        matrices_list = []
        with open(matrix_list, "r") as f:
            lines = f.readlines()
            for line in lines:
                matrices_list.append(line.strip())

    # Looping through output files
    output_path = './output'
    FC_matrix_files = glob.glob(os.path.join(output_path, "FC_matrix_data", "*"))

    # Loading one FC matrix to get its shape
    example = np.load(FC_matrix_files[0])
    N_ROI = example.shape[0]
    N_subject = len(FC_matrix_files)

    # Loading all FC matrices and taking their mean
    FC_tensor = np.zeros((N_ROI, N_ROI, N_subject))
    for k, matrix_file in enumerate(FC_matrix_files):
        if subsetSub:
            if matrix_file not in matrices_list:
                continue
        FC_matrix = np.load(matrix_file)
        FC_tensor[:,:, k] = FC_matrix
    mean_FC = np.mean(FC_tensor, axis = -1)


    ROI_names = parameters["ROI_names"]
    agg_LR = parameters["agg_LR"]

    # Plot connectogram
    if not agg_LR:
        node_angles = node_angle(ROI_names)
        fig, ax = plt.subplots(figsize = (10,10), facecolor="black", subplot_kw=dict(polar=True))
        plot_connectivity_circle(mean_FC, ROI_names, node_angles=node_angles, ax=ax)
    else:
        fig, ax = plt.subplots(figsize = (10,10), facecolor="black", subplot_kw=dict(polar=True))
        plot_connectivity_circle(mean_FC, ROI_names, ax=ax)
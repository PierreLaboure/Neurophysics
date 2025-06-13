import numpy as np
import matplotlib.pyplot as plt

from mne_connectivity.viz import plot_connectivity_circle
from mne.viz import circular_layout

import os 
import glob
import pickle
import argparse

import importlib
import sys
package_path = "/volatile/home/pl279327/Documents/Neurophysics/ROI_analysis"
if package_path not in sys.path:
    sys.path.append(package_path)

import aggregate_utils
importlib.reload(aggregate_utils)

from aggregate_utils import node_angle




def main(args = None):
    parser = argparse.ArgumentParser(description='Process some parameters.')

    parser.add_argument('--output_path', type=str, required=True,
                            help='Path to output directory')
    
    parser.add_argument('--matrix_list', type=str,
                            help='list of matrices of subject')
    
    # Parsing arguments
    args = parser.parse_args(args)
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
                matrices_list.append(os.path.basename(line.strip()).split('_RAS')[0])

    # Looping through output files
    FC_matrix_files = glob.glob(os.path.join(output_path, "FC_matrix_data", "*"))

    # Loading one FC matrix to get its shape
    example = np.load(FC_matrix_files[0])
    N_ROI = example.shape[0]
    N_subject = len(FC_matrix_files)
    if subsetSub:
        N_subject = len(matrices_list)
    # Loading all FC matrices and taking their mean
    FC_tensor = np.zeros((N_ROI, N_ROI, N_subject))
    count = 0
    for k, matrix_file in enumerate(FC_matrix_files):
        if subsetSub:
            matrix_name = os.path.basename(matrix_file).split('_FC_matrix')[0]
            if matrix_name not in matrices_list:
                continue
        FC_matrix = np.load(matrix_file)
        FC_tensor[:,:, count] = FC_matrix
        count+=1
    mean_FC = np.mean(FC_tensor, axis = -1)



    ROI_names = parameters["ROI_names"]
    dict_map = {
        'posterior_hypothalamic_nucleus right' : 'PHN',
        'posterior_hypothalamic_nucleus left' : 'PHN',
        'paraventricular_hypothalamic_nucleus_anterior_parvic right' : 'PHNAP',
        'paraventricular_hypothalamic_nucleus_anterior_parvic left' : 'PHNAP',
        'median_preoptic_nucleus middle' : 'MnPN',
        'lateral_preoptic_area right' : 'LPA',
        'lateral_preoptic_area left' : 'LPA',
        'medial_preoptic_nucleus right' : 'MlPN',
        'medial_preoptic_nucleus left' : 'MlPN',
        'lateral_hypothalamic_area right' : 'LHA',
        'lateral_hypothalamic_area left' : 'LHA',
        'mammillary_nucleus right' : 'MN',
        'mammillary_nucleus left' : 'MN',
        'dorsomedial_hypothalamus right' : 'DMH',
        'dorsomedial_hypothalamus left' : 'DMH',
        'supramammillary_nucleus middle' : 'SMN',
        'premammillary_nucleus right' : 'PMN',
        'premammillary_nucleus left' : 'PMN'
    }

    ROI_names_short = []
    for name in ROI_names:
        ROI_names_short.append(dict_map[name])

    #ROI_names = [str(k+1) for k in range(len(ROI_names))]
    agg_LR = parameters["agg_LR"]

    # Make mean FC matrix
    figure_dir = os.path.join(output_path, "Connectograms")
    os.makedirs(figure_dir, exist_ok=True)
    if subsetSub:
        figurename = os.path.join(figure_dir, "Connectogram_"+os.path.basename(matrix_list).split('.')[0]+".png")
        mean_FC_name = os.path.join(figure_dir, "mean_FC_"+os.path.basename(matrix_list).split('.')[0]+".npy")
    else:
        figurename = os.path.join(figure_dir, "Connectogram_all.eps")
        figurename_svg = os.path.join(figure_dir, "Connectogram_all.svg")
        mean_FC_name = os.path.join(figure_dir, "mean_FC_all.npy")
    np.save(mean_FC_name, mean_FC)

    # Plot connectogram
    if not agg_LR:
        node_angles = node_angle(ROI_names)
        fig, ax = plt.subplots(figsize = (15, 15), facecolor="white", subplot_kw=dict(polar=True))
        vmin = 0.1
        thr = np.count_nonzero(mean_FC>=vmin)//2

        fig.text(0.76, 0.35, "Pearson's R", fontsize = 22, rotation = -90)
        fig.text(0.62, 0.7, "Right", fontsize = 25)
        fig.text(0.2, 0.7, "Left", fontsize = 25)

        plot_connectivity_circle(mean_FC, ROI_names_short, node_angles=node_angles, node_colors = [(1, 1, 1, 1)], n_lines = thr,
                                 node_edgecolor = 'black', textcolor = 'black', facecolor = 'white', 
                                 ax=ax, vmin = vmin, vmax = 0.4, colormap = 'rainbow', 
                                 linewidth = 5, colorbar_size = 0.4, colorbar_pos=(-0.85, 0.3), fontsize_colorbar = 15,
                                 fontsize_names = 18)
    else:
        node_angles = circular_layout(ROI_names, ROI_names, start_pos=100)
        fig, ax = plt.subplots(figsize = (10,10), facecolor="black", subplot_kw=dict(polar=True))
        plot_connectivity_circle(mean_FC, ROI_names, node_angles=node_angles, ax=ax, interactive = True,
                                  colorbar_size = 0.6, colorbar_pos=(-0.7, 0.5), fontsize_names = 15, fontsize_colorbar = 15, vmin = -0.1, vmax = 0.2)
    fig.savefig(figurename, format='eps', bbox_inches='tight')
    fig.savefig(figurename_svg, format='svg', bbox_inches='tight')


if __name__ == "__main__":
    main()
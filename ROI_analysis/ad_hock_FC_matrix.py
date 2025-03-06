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

    parser.add_argument('--mean_FC_matrix', type=str, required=True,
                            help='Path to output directory')
    
    args = parser.parse_args(args)
    mean_FC_matrix = args.mean_FC_matrix

    parent = os.path.dirname(mean_FC_matrix)
    gp_path = os.path.dirname(parent)
    print(gp_path)
    parameters_path = os.path.join(gp_path, 'parameters.pkl')
    with open(parameters_path, "rb") as fp:   #Pickling
        parameters = pickle.load(fp)

    label_names = parameters["ROI_names"]

    fig, ax = plt.subplots(figsize = (15, 15))

    FC_matrix = np.load(mean_FC_matrix)

    plt.imshow(FC_matrix, cmap = 'viridis', vmin = 0, vmax = 0.6)
    ticks = np.arange(0, len(label_names))
    tick_labels = label_names
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels(tick_labels, rotation = 90)
    ax.set_yticklabels(tick_labels)
    plt.colorbar()
    plt.tight_layout()
    plt.savefig(mean_FC_matrix.replace('npy', 'png'))
    plt.title(os.path.basename(gp_path))
    plt.show()
    
if __name__ == "__main__":
    main()
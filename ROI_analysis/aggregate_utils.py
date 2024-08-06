import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from mne.viz import circular_layout

import argparse


def aggregate_ROI(ROI_path, agg_LR):
    #Create a dictionnary of aggregated labels for each big ROI demanded
    agg = pd.read_excel(ROI_path)
    agg.head()

    agg_ROI = {}
    if agg_LR:
        for agg_label in agg["hierarchy"].unique():
            agg_list = agg[agg["hierarchy"]==agg_label][["right label", "left label"]].values.ravel()
            agg_ROI[agg_label] = agg_list
    else:
        for agg_label in agg["hierarchy"].unique():
            agg_list = agg[agg["hierarchy"]==agg_label]["right label"].values.ravel()
            agg_ROI[agg_label+" right"] = agg_list
            agg_list = agg[agg["hierarchy"]==agg_label]["left label"].values.ravel()
            agg_ROI[agg_label+" left"] = agg_list

    return agg_ROI


def undersample(atlas, target_shape):
    # Undersample an atlas for lower resolution images
    zoom_factors = [s / t for t, s in zip(target_shape, atlas.shape)]
    samples = {}
    for k, shape in enumerate(target_shape):
        slice = np.floor(np.arange(shape)*zoom_factors[k]).astype(np.int64)
        samples[k] = slice
    ix = np.ix_(samples[0], samples[1], samples[2])
    return atlas[ix]




def ROI_FC(agg_ROI_labels, atlas_data, confound_image_path, fig_name, matrix_name):
    #loading confound tensor
    my_img  = nib.load(confound_image_path)
    confound_data = my_img.get_fdata()

    #Undersample the atlas
    if confound_data.shape[:3]!=atlas_data.shape:
        atlas_data = undersample(atlas_data, confound_data.shape[:-1])
    #initializing timeseries array
    ROI_timeseries = np.zeros((len(agg_ROI_labels.keys()), confound_data.shape[3]))
    #initializing label names
    label_names = agg_ROI_labels.keys()

    #flattening confound_data for faster meaning
    (kk, l, m, t) = confound_data.shape
    confound_data = confound_data.reshape(-1,t)

    for k, key in enumerate(label_names):
        #creating a mask on aggregated ROI
        mask = np.isin(atlas_data, agg_ROI_labels[key])
        bold_mask = np.where(mask.reshape(-1))
        timeseries = confound_data[bold_mask[0], :].mean(axis = 0)
        
        ROI_timeseries[k, :] = timeseries

    #correlation matrix computation
    corr_matrix = np.corrcoef(ROI_timeseries)
    #save figure without displaying it
    plt.ioff()
    plot_FC(corr_matrix, label_names)
    plt.savefig(fig_name)
    plt.ion()

    np.save(matrix_name, corr_matrix)


def plot_FC(corr_matrix, label_names):
    #plot correlation matrix without
    fig, ax = plt.subplots(figsize = (15, 15))

    plt.imshow(corr_matrix)

    ticks = np.arange(0, len(label_names))
    tick_labels = label_names
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels(tick_labels, rotation = 70)
    ax.set_yticklabels(tick_labels)
    plt.colorbar()
    plt.tight_layout()
    #plt.savefig(fig_name)


def str2bool(s):
    #for parsing
    if isinstance(s, bool):
        return s
    if s == 'True':
         return True
    elif s == 'False':
         return False
    else:
         raise argparse.ArgumentTypeError('Boolean value expected.')
    
def node_angle(ROI_names):
    #node angles calculator for connectograms
    label_names = ROI_names
    lh_labels = [name for name in label_names if name.endswith("left")]
    rh_labels = [name for name in label_names if name.endswith("right")]
    node_order = lh_labels[::-1] + rh_labels
    node_angles = circular_layout(
        label_names, node_order, start_pos=270, group_boundaries=[0, len(label_names) // 2]
    )

    return node_angles

def FC_df_tri(FC_matrix_files, short_names, group_name):
    #Create a dataframe with each line corresponding to one entry of one FC matrix
    #write the connection it represents and the group it belongs to
    df = pd.DataFrame(columns=['Connection', 'Correlation', 'Group'])
    names_array = np.array(short_names)
    p = 0
    for k, matrix_file in enumerate(FC_matrix_files):
        FC_matrix = np.load(matrix_file)
        n,m = FC_matrix.shape
        tri_idx = np.tril_indices(n, -1)
        for l, (i,j) in enumerate(zip(tri_idx[0], tri_idx[1])):
            name_combination = '-'.join((names_array[i], names_array[j]))
            Correlation = FC_matrix[i, j]
            new_line = [name_combination, Correlation, group_name]
            df.loc[p] = new_line
            p+=1
    return df

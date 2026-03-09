import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from sklearn.covariance import GraphicalLassoCV

from mne.viz import circular_layout

import argparse


def aggregate_ROI(ROI_path, agg_LR):
    #Create a dictionnary of aggregated labels for each big ROI demanded
    agg = pd.read_excel(ROI_path)

    agg_ROI = {}
    if agg_LR:
        for agg_label in agg["hierarchy"].unique():
            agg_list = agg[agg["hierarchy"]==agg_label][["right label", "left label"]].values.ravel()
            agg_ROI[agg_label] = agg_list
    else:
        for agg_label in agg["hierarchy"].unique():
            agg_list_right = agg[agg["hierarchy"]==agg_label]["right label"].values.ravel()
            agg_list_left = agg[agg["hierarchy"]==agg_label]["left label"].values.ravel()

            common = list(set(agg_list_right).intersection(agg_list_left))
            agg_list_right = [i for i in agg_list_right if i not in common]
            agg_list_left = [i for i in agg_list_left if i not in common]

            if len(agg_list_right) != 0:
                agg_ROI[agg_label+" right"] = agg_list_right
                agg_ROI[agg_label+" left"] = agg_list_left
            if len(common) != 0:
                agg_ROI[agg_label+" middle"] = common

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




def ROI_FC(agg_ROI_labels, atlas_data, confound_image_path, fig_name, matrix_name, common_mask=None):
    #loading confound tensor
    my_img  = nib.load(confound_image_path)
    confound_data = my_img.get_fdata()
    
    #Undersample the atlas
    if confound_data.shape[:-1]!=atlas_data.shape:
        atlas_data = undersample(atlas_data, confound_data.shape[:-1])
    #Crop atlas based on the commmon mask    
    if (common_mask is not None):
        confound_data = np.where(common_mask[..., np.newaxis], confound_data, np.nan) #Change done to completely remove data out of mask
    
    #initializing timeseries array
    ROI_timeseries = np.zeros((len(agg_ROI_labels.keys()), confound_data.shape[-1]))
    #initializing label names
    label_names = agg_ROI_labels.keys()

    #flattening confound_data for faster meaning
    t = confound_data.shape[-1]
    confound_data = confound_data.reshape(-1,t)

    for k, key in enumerate(label_names):
        #creating a mask on aggregated ROI
        mask = np.isin(atlas_data, agg_ROI_labels[key])
        bold_mask = np.where(mask.reshape(-1))
        timeseries = np.nanmean(confound_data[bold_mask[0], :], axis = 0) # New line with Nanmean
        
        ROI_timeseries[k, :] = timeseries

    #correlation matrix computation
    corr_matrix = np.corrcoef(ROI_timeseries)
    diag_idx = np.diag_indices(corr_matrix.shape[0])
    corr_matrix[diag_idx] = 0
    #save figure without displaying it
    plt.ioff()
    plot_FC(corr_matrix, label_names)
    plt.savefig(fig_name)
    plt.ion()

    np.save(matrix_name, corr_matrix)

def ROI_ICOV(agg_ROI_labels, atlas_data, confound_image_path, fig_name, matrix_name, common_mask=None):
    #loading confound tensor
    my_img  = nib.load(confound_image_path)
    confound_data = my_img.get_fdata()
    
    #Undersample the atlas
    if confound_data.shape[:-1]!=atlas_data.shape:
        atlas_data = undersample(atlas_data, confound_data.shape[:-1])
    #Crop atlas based on the commmon mask    
    if (common_mask is not None):
        confound_data = np.where(common_mask[..., np.newaxis], confound_data, np.nan) #Change done to completely remove data out of mask
    
    #initializing timeseries array
    ROI_timeseries = np.zeros((len(agg_ROI_labels.keys()), confound_data.shape[-1]))
    #initializing label names
    label_names = agg_ROI_labels.keys()

    #flattening confound_data for faster meaning
    t = confound_data.shape[-1]
    confound_data = confound_data.reshape(-1,t)

    for k, key in enumerate(label_names):
        #creating a mask on aggregated ROI
        mask = np.isin(atlas_data, agg_ROI_labels[key])
        bold_mask = np.where(mask.reshape(-1))
        timeseries = np.nanmean(confound_data[bold_mask[0], :], axis = 0) # New line with Nanmean
        
        ROI_timeseries[k, :] = timeseries

    #correlation matrix computation
    X = ROI_timeseries.copy()              # (T × R) e.g. (360 × 384)
    # --- standardize ---
    X = X.T
    X -= X.mean(axis=0, keepdims=True)
    X /= X.std(axis=0, keepdims=True)

    # --- 1) find valid ROI columns: at least one non-nan ---
    valid = ~np.all(np.isnan(X), axis=0)   # shape: (R,)
    Xv = X[:, valid]                       # (T × Rvalid)

    # --- 2) drop nans inside kept ROI columns (they should be gone by std) ---
    Xv = np.nan_to_num(Xv, copy=False)

    # --- 3) fit only on valid ROIs ---
    est = GraphicalLassoCV()
    est.fit(Xv)

    # --- 4) build partial correlation on valid subset ---
    prec_v = est.precision_
    d = np.sqrt(np.diag(prec_v))
    pc_v = -prec_v / np.outer(d, d)
    np.fill_diagonal(pc_v, 1.0)

    # --- 5) re-embed into full (R × R) matrix ---
    R = X.shape[1]
    ICOV = np.zeros((R, R)) * np.nan    # or zeros((R,R)) if you prefer 0-fill

    ICOV[np.ix_(valid, valid)] = pc_v

    #save figure without displaying it
    plt.ioff()
    plot_ICOV(ICOV, label_names)
    plt.savefig(fig_name)
    plt.ion()

    np.save(matrix_name, ICOV)


def plot_FC(corr_matrix, label_names):
    #plot correlation matrix without
    fig, ax = plt.subplots(figsize = (15, 15))

    plt.imshow(corr_matrix, cmap = 'viridis', vmin = 0, vmax = 1)

    ticks = np.arange(0, len(label_names))
    tick_labels = label_names
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels(tick_labels, rotation = 90)
    ax.set_yticklabels(tick_labels)
    plt.colorbar()
    plt.tight_layout()
    #plt.savefig(fig_name)

def plot_ICOV(corr_matrix, label_names):
    #plot correlation matrix without
    fig, ax = plt.subplots(figsize = (15, 15))

    plt.imshow(corr_matrix, cmap = 'seismic', vmin = -1, vmax = 1)

    ticks = np.arange(0, len(label_names))
    tick_labels = label_names
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels(tick_labels, rotation = 90)
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
    mh_labels = [name for name in label_names if name.endswith("middle")]
    lh_labels = [name for name in label_names if name.endswith("left")]
    rh_labels = [name for name in label_names if name.endswith("right")]
    node_order = mh_labels + lh_labels[::-1] + rh_labels

    if len(mh_labels)!=0:
        space = 3
        offset = 360/(len(label_names)+space/2)
        corr = offset*5/4
    else:
        corr = 0
    

    node_angles = circular_layout(
        label_names, node_order, start_pos=90-corr, group_boundaries=[0, len(mh_labels), len(lh_labels) + len(mh_labels)]
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


def get_label2roi(ROI):
    right_labels, left_labels = ROI['right label'].values, ROI['left label'].values
    labels = np.union1d(right_labels, left_labels)
    N = np.max(labels)+1
    label2roi = {}
    for label in range(N):
        ROI_row = ROI[(ROI['right label']==label) | (ROI['left label']==label)]
        roi, right_label, left_label = ROI_row['Structure'].values, ROI_row['right label'].values, ROI_row['left label'].values
        if roi.size!=0:
            right_label, left_label = right_label[0], left_label[0]
            if right_label==left_label:
                label2roi[label] = roi[0] + ' middle'
            else:
                if label == right_label:
                    label2roi[label] = roi[0] + ' right'
                else:
                    label2roi[label] = roi[0] + ' left'
    return label2roi

def fillNa_labels2roi(labels2roi):
    N = np.max(list(labels2roi.keys()))+1
    for k in range(N):
        if k not in labels2roi:
            labels2roi[k] = None
    order = list(labels2roi.keys())
    order.sort()
    sort_labels2roi = {k: labels2roi[k] for k in order}
    return sort_labels2roi, N


def compute_correlation(mode, labels2roi, confound_image_path, N, labels_map, fig_name, matrix_name):
    # Loading confound tensor
    my_img  = nib.load(confound_image_path)
    confound_data = my_img.get_fdata()

    #flattening confound_data for faster meaning
    t = confound_data.shape[-1]
    confound_data = confound_data.reshape(-1,t)

    # Initializing timeseries array
    ROI_timeseries = np.full((N, t), fill_value = np.nan)

    # Fill ROI_timeseries
    for label, roi in labels2roi.items():
        #creating a mask on aggregated ROI
        if roi is not None:
            bold_mask = np.where(np.isin(labels_map, label))[0]
            timeseries = np.nanmean(confound_data[bold_mask, :], axis = 0) # New line with Nanmean
            ROI_timeseries[label, :] = timeseries
    roi_names = list(labels2roi.values())

    if mode == 'ICOV':
        #correlation matrix computation
        X = ROI_timeseries.copy()              # (T × R) e.g. (360 × 384)
        # --- standardize ---
        X = X.T
        X -= X.mean(axis=0, keepdims=True)
        X /= X.std(axis=0, keepdims=True)

        # --- 1) find valid ROI columns: at least one non-nan ---
        valid = ~np.all(np.isnan(X), axis=0)   # shape: (R,)
        Xv = X[:, valid]                       # (T × Rvalid)

        # --- 2) drop nans inside kept ROI columns (they should be gone by std) ---
        Xv = np.nan_to_num(Xv, copy=False)

        # --- 3) fit only on valid ROIs ---
        est = GraphicalLassoCV()
        est.fit(Xv)

        # --- 4) build partial correlation on valid subset ---
        prec_v = est.precision_
        d = np.sqrt(np.diag(prec_v))
        pc_v = -prec_v / np.outer(d, d)
        np.fill_diagonal(pc_v, 1.0)

        # --- 5) re-embed into full (R × R) matrix ---
        R = X.shape[1]
        ICOV = np.zeros((R, R)) * np.nan    # or zeros((R,R)) if you prefer 0-fill

        ICOV[np.ix_(valid, valid)] = pc_v

        #save figure without displaying it
        plt.ioff()
        plot_ICOV(ICOV, roi_names)
        plt.savefig(fig_name)
        plt.ion()

        np.save(matrix_name, ICOV)
    elif mode == 'R':
        #correlation matrix computation
        corr_matrix = np.corrcoef(ROI_timeseries)
        diag_idx = np.diag_indices(corr_matrix.shape[0])
        corr_matrix[diag_idx] = 0
        #save figure without displaying it
        plt.ioff()
        plot_FC(corr_matrix, roi_names)
        plt.savefig(fig_name)
        plt.ion()

        np.save(matrix_name, corr_matrix)



def compute_alff(data, tr, fmin=0.01, fmax=0.1):
    """
    Compute ALFF for 4D fMRI data.

    Parameters
    ----------
    data : ndarray, shape (X, Y, Z, T)
        fMRI time series
    tr : float
        Repetition time (seconds)
    fmin, fmax : float
        Frequency band (Hz)

    Returns
    -------
    alff : ndarray, shape (X, Y, Z)
        ALFF map
    """
    T = data.shape[-1]
    freqs = np.fft.rfftfreq(T, d=tr)

    fft_data = np.fft.rfft(data, axis=-1)
    power = np.abs(fft_data) ** 2
    amplitude = np.sqrt(power)

    band = (freqs >= fmin) & (freqs <= fmax)
    alff = amplitude[..., band].mean(axis=-1)

    return alff

import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def aggregate_ROI(ROI_path, agg_LR):
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
    zoom_factors = [s / t for t, s in zip(target_shape, atlas.shape)]
    samples = {}
    for k, shape in enumerate(target_shape):
        slice = np.floor(np.arange(shape)*zoom_factors[k]).astype(np.int64)
        samples[k] = slice
    ix = np.ix_(samples[0], samples[1], samples[2])
    return atlas[ix]




def ROI_FC(agg_ROI_labels, atlas_data, confound_image_path, fig_name, matrix_name):
    my_img  = nib.load(confound_image_path)
    confound_data = my_img.get_fdata()

    atlas_down = undersample(atlas_data, confound_data.shape[:-1])

    ROI_timeseries = np.zeros((len(agg_ROI_labels.keys()), confound_data.shape[3]))

    label_names = agg_ROI_labels.keys()

    for k, key in enumerate(label_names):
        mask = np.isin(atlas_down, agg_ROI_labels[key])
        bold_mask = np.repeat(np.expand_dims(np.invert(mask), axis = -1), confound_data.shape[3], axis = -1)
        masked = np.ma.masked_where(bold_mask, confound_data)
        timeseries = masked.mean(axis = (0, 1, 2))
        
        ROI_timeseries[k, :] = timeseries


    corr_matrix = np.corrcoef(ROI_timeseries)
    plt.ioff()
    fig, ax = plt.subplots(figsize = (15, 15))

    plt.imshow(corr_matrix)

    ticks = np.arange(0, len(label_names))
    tick_labels = label_names
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels(tick_labels, rotation = 45)
    ax.set_yticklabels(tick_labels)
    plt.colorbar()
    plt.tight_layout()
    plt.savefig(fig_name)
    plt.ion()

    np.save(matrix_name, corr_matrix)
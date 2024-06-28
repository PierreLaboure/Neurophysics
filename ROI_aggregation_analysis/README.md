# ROI aggregation analysis

---

## Purpose : 
This directory is made to analyse functional connectivity in fMRI images between specific ROI.
* Images used as input are from RABIES confound correction. 
* Possibility to aggregate ROIs in order to treat the connectivity between groups of ROIs instead of ROI to ROI that is done in Rabies FC_matrix.
* Later, possibility to perform statistics on different subjects or aggregate the results of all subjects to get a connectogram.

# aggregate_FC.py : 

---

## Requirements : 

files needed : 

* aggregate_FC.py
* aggregate_utils.py
* ROI_autism.xlsx
* DSURQE_40micron_labels.nii

Libraries required : 

* python
* nibabel
* numpy
* matplotlib
* pandas

## Running the aggregate_FC.py : 

Example of command in a terminal : 

__python aggregate_FC.py --ROI_path "ROI_autism.xlsx" --atlas_path "DSURQE_40micron_labels.nii" --confound_path "confound" --output_path "output" --agg_LR False__

agg_LR arguments allows to aggregate left and right ROIs or to analyse them separately

Make sure you point to the adress of a "confound" directory obtained from RABIES
Make sure you have an atlas in nifti format
Make sure you have an excel sheet (example __ROI_autism.xlsx__) where : 
* There are only ROIs you are interested in
* There are columns "right label" and "left label" which contain labels corresponding to the input atlas
* There is a "hierarchy" column containing a specific name for each group of ROI you want to aggregate

## Outputs of the function : 

__aggregate_FC.py__ creates a directory output containing 2 sub-directories : 
* __FC_matrix_data__ which contains the FC_matrices in npy format
* __FC_matrix_fig__ which contains plots of the correlations matrices in png

































python aggregate_FC.py --ROI_path "ROI_autism.xlsx" --atlas_path "DSURQE_40micron_labels.nii" --confound_path "confound_PLX" --output_path "output" --agg_LR False
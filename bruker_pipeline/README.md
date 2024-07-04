# Bruker Pipeline

---

## Purpose : 

This directory is made to convert raw bruker data directly obtained after acquiring scans into BIDS framework. __This pipeline only works with fMRI acquisitions for now__. Commands to carry out analysis are also given at the end of __pipeline.sh__

## Using this pipeline : 

This pipeline requires the following files : 
* pipeline.sh
* clean_scans.py
* concat_bold.py

It requires the following libraries : 
* brkraw (python)
* AFNI (linux)
* numpy
* pandas
* nibabel

  
## Running the pipeline : 

Once downloaded, you must activate the .sh scripts via : chmod +x script.sh

In a linux Terminal : 
	pipeline.sh "input_data_directory" "output directory

Example : 
	pipeline.sh "/media/rgolgolab/WD6/Alicia/Resting-state/Raw_data/Females/Afterttt" "./full_pipeline"

Make sure your output directory contains a file named __Scans.xlsx__ With only 2 colunms like in the given example.
* One of them must contain subject names like : "AN2165".
* The second one containing scan IDs like : "E6" or "E10".


This pipeline will carry out the following actions : 
* Convert Raw data to Helper
		* Remove unwanted colunms and change some entries
		* Remove rows that are not useful scans
		* add T2w or BOLD tags to scans
* Convert data to BIDS
* deoblique all NIFTI images
* concatenate all bold runs for each subject

Data is now ready for processing

## nii2deo.sh : 

You can also run the deoblique code as a standalone if your data is already in BIDS framework via command : nii2deo.sh bids

This function will deoblique all images but won't concatenate bold runs. Doesn't require python.

# Rabies processing

---

## Requirements : 

* Make sure rabies-0.4.7.simg is installed
* Make sure you have a direcory containing your "bids" directory and 3 empty directories : "preprocess", "confound", "analysis"
* Make sure that the path pointing to RABIES is the right one


## STEP 1 : Preprocessing

singularity run -B PATH/bids:/bids:ro -B PATH/preprocess:/preprocess /media/rgolgolab/WD6/rabies-0.4.7.simg -p MultiProc preprocess /bids /preprocess --apply_STC --TR 1.5

## STEP 2 : Confound correction

singularity run -B PATH/bids:/bids:ro -B PATH/preprocess:/preprocess -B PATH/confound:/confound /media/rgolgolab/WD6/rabies-0.4.7.simg confound_correction /preprocess /confound --highpass 0.01 --smoothing_filter 0.35 --lowpass 0.1 --conf_list WM_signal CSF_signal mot_6


## STEP 3 : analysis

singularity run -B PATH/bids:/bids:ro -B PATH/preprocess:/preprocess -B PATH/confound:/confound -B PATH/analysis:/analysis /media/rgolgolab/WD6/rabies-0.4.7.simg analysis /confound /analysis --group_ica apply=true,dim=10,random_seed=1 --FC_matrix

More complex analysis commands will be detailed elsewhere like the following : 

singularity run -B ./bids:/bids:ro -B ./preprocess:/preprocess -B ./confound:/confound -B ./analysis_mot:/analysis_mot -B ./list:/list /media/rgolgolab/WD6/rabies-0.4.7.simg analysis /confound /analysis_mot --group_ica apply=true,dim=10,random_seed=1 --seed_list /list/MOT.nii.gz --FC_matrix 

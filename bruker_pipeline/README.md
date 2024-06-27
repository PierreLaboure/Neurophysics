Running the pipeline : 

In Terminal : 
	pipeline.sh "/media/rgolgolab/WD6/Alicia/Resting-state/Raw_data/Females/Afterttt" "./full_pipeline"

Make sure your output directory contains a file "Scans.xlsx" With only 2 colunms.
	One of them must contains subject names like : "AN2165".
	The second one containing scan IDs like : "E6" or "E10".
See file in /media/rgolgolab/WD6/PierrePrePro/full_pipeline for example.

Will do the following : 
	-Convert Raw data to Helper
		-Remove unwanted colunms and change some entries
		-Remove rows that are not useful scans
		-add T2w or BOLD tags to scans
	-Convert data to BIDS
	-deoblique all NIFTI images
	-concatenate all bold runs of subjects

Data is now ready for processing


Commands for processing : 

make sure you have a direcory containing your "bids" directory and 3 empty directories : "preprocess", "confound", "analysis"
make sure that the path pointing to RABIES is the right one




STEP 1 : Preprocessing

singularity run -B PATH/bids:/bids:ro -B PATH/preprocess:/preprocess /media/rgolgolab/WD6/rabies-0.4.7.simg -p MultiProc preprocess /bids /preprocess --apply_STC --TR 1.5



STEP 2 : Confound correction

singularity run -B PATH/bids:/bids:ro -B PATH/preprocess:/preprocess -B PATH/confound:/confound /media/rgolgolab/WD6/rabies-0.4.7.simg confound_correction /preprocess /confound --highpass 0.01 --smoothing_filter 0.35 --lowpass 0.1 --conf_list WM_signal CSF_signal mot_6



STEP 3 : analysis

singularity run -B PATH/bids:/bids:ro -B PATH/preprocess:/preprocess -B PATH/confound:/confound -B PATH/analysis:/analysis /media/rgolgolab/WD6/rabies-0.4.7.simg analysis /confound /analysis --group_ica apply=true,dim=10,random_seed=1 --FC_matrix



singularity run -B ./bids:/bids:ro -B ./preprocess:/preprocess -B ./confound:/confound -B ./analysis_mot:/analysis_mot -B ./list:/list /media/rgolgolab/WD6/rabies-0.4.7.simg analysis /confound /analysis_mot --group_ica apply=true,dim=10,random_seed=1 --seed_list /list/MOT.nii.gz --FC_matrix 

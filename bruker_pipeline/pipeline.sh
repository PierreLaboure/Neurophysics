#!/bin/bash

#out_data_dir must contain a file called Scans.xlsx

insert_deo() {
	local input_string="$1"
	if [[ "$input_string" == *_bold.nii.gz ]]; then
		echo "${input_string/_bold.nii.gz/_deoblique_bold.nii.gz}"
	elif [[ "$input_string" == *T2w.nii.gz ]]; then
		echo "${input_string/_T2w.nii.gz/_deoblique_T2w.nii.gz}"
	else
		echo "$input_string"
	fi
}

raw_data_dir="$1"
out_data_dir="$2"
out_name="Helper"

brkraw bids_helper "$raw_data_dir" "$out_data_dir/$out_name" -j

mv -v "$out_data_dir/${out_name::-1}.json" "$out_data_dir/${out_name}.json"

filePath="$out_data_dir/${out_name}.csv"

#process bids_helper
/usr/bin/awk -F, '(FNR==1||$6=="func"||$6=="anat") {print}' "$filePath" |\
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {if (NR>1) {$3=""}} { print }'|\
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {if ($6=="func") {$13="bold"} if ($6=="anat") {$13="T2w"} print }' |\
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {gsub(/Underscore/,"",$2)} { print }' > tmp && mv tmp $filePath

#removing useless scans
source /home/rgolgolab/anaconda3/bin/activate
python clean_scans.py "$filePath" "$out_data_dir/Scans.xlsx"

#converting to bids
brkraw bids_convert "$raw_data_dir" "$out_data_dir/$out_name.csv" -j "$out_data_dir/$out_name.json" -o "$out_data_dir/bids"




bids_dir="$out_data_dir/bids"

for subject_dir in "$bids_dir"/sub*/; do
    # Inside each subject directory
    echo "Processing $subject_dir"

    # Navigate to the func directory
    func_dir="${subject_dir}func/"

    # Check if the func directory exists
    if [ -d "$func_dir" ]; then
        # Find the .nii.gz files in the func directory with run-01 and run-02 in their names
        run01_file=$(find "$func_dir" -type f -name "*run-01*.nii.gz")
        run02_file=$(find "$func_dir" -type f -name "*run-02*.nii.gz")

        # Process the .nii.gz files
        if [ -n "$run01_file" ]; then
            echo "Found run-01 file: $run01_file"
            # Add your processing command here, e.g., cat, cp, etc.
            # Example: cat "$run01_file"
	    deo_name=$(insert_deo "$run01_file")
	    3dWarp -oblique2card -prefix "$deo_name" "$run01_file"
	    rm "$run01_file"
        else
            echo "No run-01 .nii.gz file found in $func_dir"
        fi

        if [ -n "$run02_file" ]; then
            echo "Found run-02 file: $run02_file"
            # Add your processing command here, e.g., cat, cp, etc.
            # Example: cat "$run02_file"
	    deo_name=$(insert_deo "$run02_file")
	    3dWarp -oblique2card -prefix "$deo_name" "$run02_file"
	    rm "$run02_file"
        else
            echo "No run-02 .nii.gz file found in $func_dir"
        fi
    else
        echo "Directory $func_dir does not exist"
    fi

    # Navigate to the anat directory
    anat_dir="${subject_dir}anat/"

    # Check if the anat directory exists
    if [ -d "$anat_dir" ]; then
        # Find the .nii.gz files in the anat directory
        T2w_file=$(find "$anat_dir" -type f -name "*.nii.gz")

        # Process the .nii.gz files
        if [ -n "$T2w_file" ]; then
            echo "Found anat file: $T2w_file"
            # Add your processing command here, e.g., cat, cp, etc.
            # Example: cat "$T2w_file"
	    deo_name=$(insert_deo "$T2w_file")
	    3dWarp -oblique2card -prefix "$deo_name" "$T2w_file"
	    rm "$T2w_file"
        else
            echo "No T2w .nii.gz file found in $anat_dir"
        fi
    else
        echo "Directory $anat_dir does not exist"
    fi


done

python concat_bold.py "$bids_dir"

mkdir "$out_data_dir/preprocess"
mkdir "$out_data_dir/confound"
mkdir "$out_data_dir/analysis"


#singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess rabies-0.4.7.simg -p MultiProc preprocess /bids /preprocess --apply_STC --TR 1.5
#singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess -B $out_data_dir/confound:/confound rabies-0.4.7.simg confound_correction /preprocess /confound --highpass 0.01 --smoothing_filter 0.35 --lowpass 0.1 --conf_list WM_signal CSF_signal mot_6
#singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess -B $out_data_dir/confound:/confound -B $out_data_dir/analysis:/analysis rabies-0.4.7.simg analysis /confound /analysis --group_ica apply=true,dim=10,random_seed=1 --FC_matrix
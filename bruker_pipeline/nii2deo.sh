#!/bin/bash

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

insert_bold() {
    	local input_string="$1"
    	if [[ ! "$input_string" =~ _bold\.nii\.gz$ ]]; then
        	echo "${input_string%.nii.gz}_bold.nii.gz"
    	else
        	echo "$input_string"
    	fi
}

insert_T2w() {
    	local input_string="$1"
    	if [[ ! "$input_string" =~ _T2w\.nii\.gz$ ]]; then
        	echo "${input_string%.nii.gz}_T2w.nii.gz"
    	else
        	echo "$input_string"
    	fi
}


bids_dir="$1"


# Loop through each subject directory
for subject_dir in "$bids_dir"/sub*/; do
    # Inside each subject directory
    echo "Processing $subject_dir"

    # Define the path to the func directory
    func_dir="${subject_dir}func/"

    # Check if the func directory exists
    if [ -d "$func_dir" ]; then
        # Find the .nii.gz files in the func directory ending with _EPI, _bold, or _T2w
        files=$(find "$func_dir" -type f \( -name "*.nii.gz"  \))

        # Process each found file
        for file in $files; do
            echo "Found file: $file"
            bold_file=$(insert_bold "$file")
            deo_name=$(insert_deo "$bold_file")
            3dWarp -oblique2card -prefix "$deo_name" "$file"
	    rm "$file"
        done
    else
        echo "Directory $func_dir does not exist"
    fi

    anat_dir="${subject_dir}anat/"

    #check if anat directory exists
    if [ -d "$anat_dir" ]; then
	files=$(find "$anat_dir" -type f \( -name "*.nii.gz"  \))

	#¶rocess files found
	for file in $files; do
	   echo "found file : $file"
       T2w_file=$(insert_T2w "$file")
	   deo_name=$(insert_deo "$T2w_file")
           3dWarp -oblique2card -prefix "$deo_name" "$file"
	   rm "$file"

	done
    else
	echo "Directory $anat_dir does not exist"
    fi

done

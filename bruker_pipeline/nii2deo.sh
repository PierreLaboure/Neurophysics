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

usage() {
    echo "Usage: $0 <bids_dir>"
    echo "  bids_dir     Mandatory argument for bids directory"
    echo "Options:"
    echo "  -v, --verbose   How much this function talks   "
    echo "  -h, --help      Show this help message and exit"
    exit 1
}

# Check if at least one arguments is provided
if [ "$#" -lt 1 ]; then
    usage
fi

#default values
verbose=1

#Assign required arguments
bids_dir="$1"

shift
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then  # Check if next argument exists and is a number
                verbose="$2"
                shift 2  # Move past both '-d' and its value
            else
                echo "Error: wrong input type for verbose : '$1'" >&2
                exit 1
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            exit 1
            ;;
    esac
done

# Set LOG_OUTPUT dynamically
if [[ $verbose == 1 ]]; then
    LOG_OUTPUT="/dev/stdout"  # Normal output
else
    LOG_OUTPUT="/dev/null"  # Suppress output
fi

# Logging function
log() {
    echo "[LOG]: $@" > "$LOG_OUTPUT"
}

# Loop through each subject directory
for subject_dir in "$bids_dir"/sub*/; do
    # Inside each subject directory
    log "Processing $subject_dir"

    # Define the path to the func directory
    func_dir="${subject_dir}func/"

    # Check if the func directory exists
    if [ -d "$func_dir" ]; then
        # Find the .nii.gz files in the func directory ending with _EPI, _bold, or _T2w
        files=$(find "$func_dir" -type f \( -name "*.nii.gz"  \))

        # Process each found file
        for file in $files; do
            log "Found file: $file"
            bold_file=$(insert_bold "$file")
            deo_name="$bold_file"
            3dTshift -prefix "$func_dir/temp.nii.gz" -tpattern altminus "$file" > "$LOG_OUTPUT"
            rm "$file"
            3dWarp -oblique2card -prefix "$deo_name" "$func_dir/temp.nii.gz" > "$LOG_OUTPUT"

		rm "$func_dir/temp.nii.gz"
        done
    else
        echo "Directory $func_dir does not exist"
    fi

    anat_dir="${subject_dir}anat/"

    #check if anat directory exists
    if [ -d "$anat_dir" ]; then
        files=$(find "$anat_dir" -type f \( -name "*.nii.gz"  \))

        #Process files found
        for file in $files; do
            log "found file : $file"
            T2w_file=$(insert_T2w "$file")
            deo_name="$T2w_file"
            3dWarp -oblique2card -prefix "$anat_dir/temp.nii.gz" "$file" > "$LOG_OUTPUT"
            rm "$file"
            mv "$anat_dir/temp.nii.gz" "$deo_name"
        done
    else
	    echo "Directory $anat_dir does not exist"
    fi

done

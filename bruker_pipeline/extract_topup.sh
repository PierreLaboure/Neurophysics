#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 06/02/2025 by Pierre Labouré

# Read functional scans in a bids directory. Backpropagate to the raw data directory and identify which scans are data and which are made
# For topup correction. Extract these ones and make the difference depending on forward and backward PE

#==============================================================================
#==============================================================================


usage() {
    echo "Usage: $0 <raw_data_dir> <out_data_dir>"
    echo "  raw_data_dir     Mandatory argument for raw directory"
    echo "  out_data_dir     Mandatory argument for output directory"
    exit 1
}

# Check if at least two arguments are provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Assign required arguments
raw_data_dir="$1"
out_data_dir="$2"

bids_dir="$out_data_dir/bids"
helper_path="$out_data_dir/Helper.csv"


find "$bids_dir" -mindepth 1 -maxdepth 1 -type d -name 'sub-*' | while read dir; do
    # extract subjID name inside of bids dir
    dir_name=$(basename "$dir")
    subjID="${dir_name#*"sub-"}"

    #Using Helper.csv, get the raw name of the corresponding subject
    rawdata=$(awk -F',' -v id="$subjID" '
        NR==1 {
            for (i=1; i<=NF; i++) {
                if ($i ~ /SubjID/) subj_col=i;
                if ($i ~ /RawData/) raw_col=i;
            }
            next;
        }
        $subj_col == id { print $raw_col; exit }
    ' "$helper_path")

    #Backpropagate to raw data dir and get inside selected subject
    subj_raw_data_dir="$raw_data_dir/$rawdata"

    #Read functional scans inside of bids subject directory and find its scan number: 
    find "$dir/func" -mindepth 1 -maxdepth 1 -type f -name '*.json' | while read json_file; do
        #find corresponding image name:
        nifti_file="${json_file%%.json}.nii.gz"
        #find out if scan is data or made for topup correction
        acq_duration=$(jq -r .AcquisitionDuration "$json_file")
        if [ "$acq_duration" == "600.0" ]; then
            is_topup=0
        else
            scan_number=$(jq -r .PulseSequenceDetails "$json_file")
            scan_number="${scan_number#*10ms (E}"
            scan_number="${scan_number%%)*}"

            method_path="$subj_raw_data_dir/$scan_number/method"
            encoding=$(awk -F'=' '/##\$ReversePE=/ {print $2}' "$method_path")

            if [ "$encoding" == "WholeExp" ]; then
                mv "$nifti_file" "$dir/func/reversePE.nii.gz"
                mv "$json_file" "$dir/func/reversePE.json"
            else
                mv "$nifti_file" "$dir/func/forwardPE.nii.gz"
                mv "$json_file" "$dir/func/forwardPE.json"
            fi

        fi

    done


done
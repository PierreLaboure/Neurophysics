#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 07/02/2025 by Pierre Labouré

# Move functional scans and the forward/reversePE scans to a TEMP dir
# Compute topup processing, apply it to functional data and return it to their original dir
#==============================================================================
#==============================================================================


# Function to display usage information
usage() {
    echo "Usage: $0 <bids_dir> <acqparams>"
    echo ""
    echo "Arguments:"
    echo "  bids_dir      Mandatory argument for input bids directory"
    echo "  acq_params    Mandatory argument path to acqparams.txt file"
    echo "  swell_factor  Mandatory argument factor to swell subject to human dimensions"
    echo "Options:"
    echo "  -v, --verbose      How much this function talks   "
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least 2 arguments (bids_dir, acqparams) is provided
if [[ $# -lt 2 ]]; then
    echo "Error: Missing mandatory argument <bids_dir> <acqparams>." >&2
    usage
fi

# Default values
verbose=1
swell_factor=10 #mouse

# Assign required first argument
bids_dir="$1"
acq_params="$2"
swell_factor="$3"

shift 3 # Move past the first 2 arguments


# Parse optional arguments
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

if [[ $verbose == 1 ]]; then
    LOG_OUTPUT="/dev/stdout"  # Normal output
else
    LOG_OUTPUT="/dev/null"  # Suppress output
fi

# Logging function
log() {
    echo "[LOG]: $@" > "$LOG_OUTPUT"
}

source "$(conda info --base)/etc/profile.d/conda.sh" > /dev/null 2>&1
conda activate stable312 > /dev/null 2>&1
swell_script="$(pwd)/swell.py"

TEMP_FOLDER=$(mktemp -d)

topuper () {
    bids_dir="$1"
    dir="$2"
    TEMP_FOLDER="$3"

    func_dir="$dir/func"
    dirname="${dir#$bids_dir/}"
    log "Topup processing for subject $dirname"

    temp_sub_dir="$TEMP_FOLDER/$dirname"
    mkdir "$temp_sub_dir"
    find "$func_dir" -maxdepth 1 -type f -exec cp {} "$temp_sub_dir" \;

    bold_data_file=$(find "$func_dir" -type f -name "*_bold.nii.gz" | head -n 1)
    dim4=$(fslval "$bold_data_file" dim4)
    dim4_minus1=$((dim4 - 1))

    #Fsl operations : 
    #Time average of foward and backward PE
    fslmaths "$temp_sub_dir/forwardPE.nii.gz" -Tmean "$temp_sub_dir/meanFor.nii.gz"
    fslmaths "$temp_sub_dir/reversePE.nii.gz" -Tmean "$temp_sub_dir/meanRev.nii.gz"

    #Merging Forward PE and Backward PE means for TOPUP function
    fslmerge -t "$temp_sub_dir/ForRev.nii.gz" "$temp_sub_dir/meanFor.nii.gz" "$temp_sub_dir/meanRev.nii.gz"

    #TO DO : allow to change the swell factor "10"
    # Swell the image by a factor of 10 and transpose it to be in human orientation
    python "$swell_script" -i "$temp_sub_dir/ForRev.nii.gz" -s $swell_factor
    
    log "Computing topup correction"
    topup --imain="$temp_sub_dir/ForRev_SwellT.nii.gz" --datain="$acq_params" --config=b02b0.cnf --out="$temp_sub_dir/topup" --nthr=20 --subsamp=1 --verbose > "$LOG_OUTPUT"


    python "$swell_script" -i "$temp_sub_dir/reversePE.nii.gz" -s $swell_factor
    fslroi "$temp_sub_dir/reversePE_SwellT.nii.gz" "$temp_sub_dir/reversePE_SwellT0.nii.gz" 0 1
    fslmerge -t "$temp_sub_dir/reverse2apply.nii.gz" "$temp_sub_dir/reversePE_SwellT0.nii.gz" $(for i in $(seq 1 $dim4_minus1); do echo "$temp_sub_dir/reversePE_SwellT0.nii.gz"; done)


    find "$temp_sub_dir" -type f -name '*bold.nii.gz' | while read bold_file; do
        bold_file_name=$(basename "$bold_file")
        log "Applying topup correction on $bold_file_name for subject $dirname"

        python "$swell_script" -i "$bold_file" -s $swell_factor
        swell_bold_file="${bold_file%%".nii.gz"}_SwellT.nii.gz"
        applytopup --imain="$swell_bold_file","$temp_sub_dir/reverse2apply.nii.gz" --topup="$temp_sub_dir/topup" --datain="$acq_params" --inindex=1,2 --out="$temp_sub_dir/corrected.nii.gz" --verbose > "$LOG_OUTPUT"
        python "$swell_script" -i "$temp_sub_dir/corrected.nii.gz" -s $swell_factor --inverse 1
        rm -f "$bold_file"
        mv "$temp_sub_dir/corrected_UnSwellT.nii.gz" "$bold_file"
    done

    find "$temp_sub_dir" -type f -name '*bold.*' | while read bold_file; do
        bold_file_name=$(basename "$bold_file")
        mv -f "$bold_file" "$func_dir/$bold_file_name"
    done
    find "$func_dir" -maxdepth 1 -type f -name '*PE*' -exec rm -f {}  \;

}


find "$bids_dir" -type d -name 'sub-*' | while read dir; do
    has_ses_dirs=false
    # Look for ses-* subdirectories inside sub-*
    for ses_dir in "$dir"/ses-*; do
        if [ -d "$ses_dir" ]; then
            has_ses_dirs=true
            # Check if this ses-* dir contains both anat and func
            if [ -d "$ses_dir/anat" ] && [ -d "$ses_dir/func" ]; then
                # Output relative path from bids_dir
                ## sub_dirname="${ses_dir#$bids_dir/}"
                echo "Exploring $ses_dir"
                topuper "$bids_dir" "$ses_dir" "$TEMP_FOLDER"
            fi
        fi
    done

    # If no ses-* subdirs, check sub-* dir directly
    if [ "$has_ses_dirs" = false ]; then
        if [ -d "$dir/anat" ] && [ -d "$dir/func" ]; then
            ## sub_dirname="${dir#$bids_dir/}"
            echo "Exploring $dir"
            topuper "$bids_dir" "$dir" "$TEMP_FOLDER"
        fi
    fi
done


rm -rf "$TEMP_FOLDER"
#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 29/01/2025 by Pierre Labouré

# Applied to a bids folder. Rigidely register a functional run to its anatomical scan to mask this anatomical scan.
#==============================================================================
#==============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 <bids_dir>"
    echo ""
    echo "Arguments:"
    echo "  bids_dir     Mandatory argument for input bids directory"
    echo "Options:"
    echo "  -v, --verbose      How much this function talks   "
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (bids_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <bids_dir>." >&2
    usage
fi

# Default values
verbose=1

# Assign required first argument
bids_dir="$1"
shift  # Move past the first argument


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

source "$(conda info --base)/etc/profile.d/conda.sh" > /dev/null 2>&1
conda activate stable312 > /dev/null 2>&1
crop_script="$(pwd)/crop_img2rigidReg.py"

TEMP_FOLDER=$(mktemp -d)

#IS_crop=$(jq -r .crop_anat.IS_crop config.json)

cropper() {

    dir="$1"
    TEMP_FOLDER="$2"

    IS_crop=$(jq -r .crop_anat.IS_crop config.json)
    sub_func_dir="$dir/func"
    sub_anat_dir="$dir/anat"

    func_img=$(find "$sub_func_dir" -type f -name '*.nii.gz' | sort | tail -n 1)
    anat_img=$(find "$sub_anat_dir" -type f -name '*.nii.gz' | sort | head -n 1)
    fslroi "$anat_img" "$anat_img" 0 -1 0 -1 $IS_crop -1
    frame0func_path="$TEMP_FOLDER/func0.nii.gz"
    fslroi "$func_img" "$frame0func_path" 10 1
    antsRegistrationSyN.sh -d 3 -f "$anat_img" -m "$frame0func_path" -o "$TEMP_FOLDER/R" -n 20 -t 'r' > "$LOG_OUTPUT"

    python "$crop_script" -i "$anat_img" -r "$TEMP_FOLDER/RWarped.nii.gz" > "$LOG_OUTPUT"
    rm -f "$anat_img"
    mv "$sub_anat_dir/crop.nii.gz" "$anat_img"
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
                cropper "$ses_dir" "$TEMP_FOLDER"
            fi
        fi
    done

    # If no ses-* subdirs, check sub-* dir directly
    if [ "$has_ses_dirs" = false ]; then
        if [ -d "$dir/anat" ] && [ -d "$dir/func" ]; then
            ## sub_dirname="${dir#$bids_dir/}"
            echo "Exploring $dir"
            cropper "$dir" "$TEMP_FOLDER"
        fi
    fi
done


rm -rf "$TEMP_FOLDER"
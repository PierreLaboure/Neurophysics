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
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (bids_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <bids_dir>." >&2
    usage
fi

# Assign required first argument
bids_dir="$1"
shift  # Move past the first argument


# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            ;;
    esac
    shift
done

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate stable312
crop_script="$(pwd)/crop_img2rigidReg.py"

TEMP_FOLDER=$(mktemp -d)



find "$bids_dir" -mindepth 1 -maxdepth 1 -type d -name 'sub-*' | while read dir; do
    sub_func_dir="$dir/func"
    sub_anat_dir="$dir/anat"

    func_img=$(find "$sub_func_dir" -type f -name '*.nii.gz' -print -quit)
    anat_img=$(find "$sub_anat_dir" -type f -name '*.nii.gz' -print -quit)

    antsRegistrationSyN.sh -d 3 -f "$anat_img" -m "$func_img" -o "$TEMP_FOLDER/R" -n 20 -t 'r'

    python "$crop_script" -i "$anat_img" -r "$TEMP_FOLDER/RWarped.nii.gz"
    rm -f "$anat_img"
    mv "$sub_anat_dir/crop.nii.gz" "$anat_img"

done

rm -rf "$TEMP_FOLDER"
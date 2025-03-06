#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 07/02/2025 by Pierre Labouré

# Applied to a bids folder and path to an Atlas template.
# Rigidely register croped Anatomical scans to the atlas template
#==============================================================================
#==============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 <process_dir> <template_path>"
    echo ""
    echo "Arguments:"
    echo "  process_dir     Mandatory argument for input processing directory which contains bids dir and rabies dirs"
    echo "  template_path   Mandatory argument for path to atlas template in .nii format"
    echo "Options:"
    echo "  -h, --help         Show this help message and exit"
    exit 1
}


# Ensure at least one argument (bids_dir) is provided
if [[ $# -lt 2 ]]; then
    echo "Error: Missing mandatory argument <process_dir> <template_path> ." >&2
    usage
fi

# Assign required first argument
process_dir="$1"
template_path="$2"
shift 2  # Move past the first 2 arguments

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

mkdir -p "$process_dir/croped_template"
croped_template="$process_dir/croped_template/croped_template.nii"
cp "$template_path" "$croped_template"

bids_dir="$process_dir/bids"

count=0
find "$bids_dir" -mindepth 1 -maxdepth 1 -type d -name 'sub-*' | while read dir; do
    ((count++))
    sub_anat_dir="$dir/anat"

    anat_img=$(find "$sub_anat_dir" -type f -name '*.nii.gz' -print -quit)

    antsRegistrationSyN.sh -d 3 -f "$croped_template" -m "$anat_img" -o "$TEMP_FOLDER/R${count}" -n 20 -t 'r'
done

find "$TEMP_FOLDER" -type f -regex '.*/R[0-9]+Warped\.nii\.gz' | while read file; do
    python "$crop_script" -i "$croped_template" -r "$file" --inplace 1
done

rm -rf "$TEMP_FOLDER"
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
    echo "Usage: $0 <process_dir>"
    echo ""
    echo "Arguments:"
    echo "  process_dir     Mandatory argument for input processing directory which contains bids dir and rabies dirs"
    echo "Options:"
    echo "  -v, --verbose      How much this function talks   "
    echo "  -h, --help         Show this help message and exit"
    exit 1
}


# Ensure at least one argument (bids_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <process_dir> ." >&2
    usage
fi

# Default values
verbose=1

# Assign required first argument
process_dir="$1"
shift 1  # Move past the first argument

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

source "$(conda info --base)/etc/profile.d/conda.sh" > /dev/null 2>&1
conda activate stable312 > /dev/null 2>&1
crop_script="$(pwd)/crop_img2rigidReg.py"

TEMP_FOLDER=$(mktemp -d)
#TEMP_FOLDER="$process_dir/save"
#mkdir "$TEMP_FOLDER"

template_path=$(jq -r .crop_atlas.template2crop_path config.json)
croped_template="$process_dir/croped_template/croped_template.nii"
cp "$template_path" "$croped_template"

labels_path=$(jq -r .crop_atlas.labels2copy_path config.json)
croped_labels="$process_dir/croped_template/croped_labels.nii.gz"
cp "$labels_path" "$croped_labels"

template_mask_path=$(jq -r .crop_atlas.mask2crop_path config.json)
croped_mask="$process_dir/croped_template/croped_mask.nii.gz"
cp "$template_mask_path" "$croped_mask"

CSFmask_path=$(jq -r .crop_atlas.CSFmask2crop_path config.json)
croped_CSFmask="$process_dir/croped_template/croped_CSFmask.nii.gz"
cp "$CSFmask_path" "$croped_CSFmask"

WMmask_path=$(jq -r .crop_atlas.WMmask2crop_path config.json)
croped_WMmask="$process_dir/croped_template/croped_WMmask.nii.gz"
cp "$WMmask_path" "$croped_WMmask"

#Vascular_mask_path=$(jq -r .crop_atlas.Vascular_mask2crop_path config.json)
#croped_Vascular_mask="$process_dir/croped_template/croped_Vascular_mask.nii.gz"
#cp "$Vascular_mask_path" "$croped_Vascular_mask"

bids_dir="$process_dir/bids"

count=0
find "$bids_dir" -mindepth 1 -maxdepth 1 -type d -name 'sub-*' | while read dir; do
    ((count++))
    sub_anat_dir="$dir/anat"
    anat_img=$(find "$sub_anat_dir" -type f -name '*.nii.gz' | sort | head -n 1)
    antsRegistrationSyN.sh -d 3 -f "$croped_template" -m "$anat_img" -o "$TEMP_FOLDER/R${count}" -n 20 -t 'r' > "$LOG_OUTPUT"

done

find "$TEMP_FOLDER" -type f -regex '.*/R[0-9]+Warped\.nii\.gz' | while read file; do
    python "$crop_script" -i "$croped_template" -r "$file" --inplace 1 > "$LOG_OUTPUT"
    python "$crop_script" -i "$croped_labels" -r "$file" --inplace 1 > "$LOG_OUTPUT"
    python "$crop_script" -i "$croped_mask" -r "$file" --inplace 1 > "$LOG_OUTPUT"
    python "$crop_script" -i "$croped_CSFmask" -r "$file" --inplace 1 > "$LOG_OUTPUT"
    python "$crop_script" -i "$croped_WMmask" -r "$file" --inplace 1 > "$LOG_OUTPUT"
    #python "$crop_script" -i "$croped_Vascular_mask" -r "$file" --inplace 1 > "$LOG_OUTPUT"
done

rm -rf "$TEMP_FOLDER"
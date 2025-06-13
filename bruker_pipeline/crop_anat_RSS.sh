#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 06/03/2025 by Pierre Labouré

# Applied to a processing dir, use RSS masks of bold images to crop corresponding anatomical scans
#==============================================================================
#==============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 <process_dir>"
    echo ""
    echo "Arguments:"
    echo "  process_dir     Mandatory argument for input bids directory"
    echo "Options:"
    echo "  -v, --verbose      How much this function talks   "
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (process_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <process_dir>." >&2
    usage
fi

# Default values
verbose=1

# Assign required first argument
process_dir="$1"
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


TEMP_FOLDER=$(mktemp -d)
mkdir -p "$TEMP_FOLDER/masks" "$TEMP_FOLDER/transforms"

find "$process_dir/bids" -type d -name 'sub-*' | while read dir; do
    subname=$(basename "$dir")

    sub_anat_dir="$process_dir/bids/$subname/anat"
    sub_func_dir="$process_dir/bids/$subname/func"

    anat_img=$(find "$sub_anat_dir" -type f -name '*.nii.gz' | sort | head -n 1)
    func_img=$(find "$sub_func_dir" -type f -name '*.nii.gz' | sort | tail -n 1)

    filename=$(basename "$func_img" .nii.gz)
    RSS_mask="$process_dir/RSS/bold/$subname/${filename}.nii.gz"

    fslroi "$anat_img" "$anat_img" 0 -1 0 -1 55 -1

    antsRegistrationSyN.sh -d 3 -f "$anat_img" -m "$file" -o "$TEMP_FOLDER/transforms/${filename}" -n 20 -t 'r' > "$LOG_OUTPUT"
    antsApplyTransforms -d 3 -i "$RSS_mask" -r "$anat_img" -o "$TEMP_FOLDER/masks/${filename}.nii.gz" -t "$TEMP_FOLDER/transforms/${filename}0GenericAffine.mat" > "$LOG_OUTPUT"
    fslmaths "$anat_img" -mul "$TEMP_FOLDER/masks/${filename}.nii.gz" "${anat_img}"

done

rm -rf "$TEMP_FOLDER"
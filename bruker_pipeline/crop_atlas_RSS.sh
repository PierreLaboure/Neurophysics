#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 06/03/2025 by Pierre Labouré

# Applied to a bids folder and path to an Atlas template.
# Rigidely register bolds scans to the atlas template,
# Apply transformations to RSS masks,
# Mask all template with product of all masks in template space
#==============================================================================
#==============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 <process_dir>"
    echo ""
    echo "Arguments:"
    echo "  process_dir     Mandatory argument for input processing directory which contains bids dir RSS dir"
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


TEMP_FOLDER=$(mktemp -d)
mkdir -p "$TEMP_FOLDER/masks" "$TEMP_FOLDER/transforms"
mkdir -p "$process_dir/masks" "$process_dir/croped_template"

# Copying template to process dir
template_path=$(jq -r .crop_atlas.template2crop_path config.json)
croped_template="$process_dir/croped_template/croped_template.nii.gz"
cp "$template_path" "$croped_template"


bids_dir="$process_dir/bids"

#Register all bold scans to anatomical template and apply transformation to the RSS masks
#Convert masks to int
find "$bids_dir" -type f -name '*bold.nii.gz' | while read file; do
    filename=$(basename "$file" .nii.gz)
    subname="${filename%%_task*}"
    RSS_mask="$process_dir/RSS/bold/$subname/${filename}.nii.gz"
    
    antsRegistrationSyN.sh -d 3 -f "$croped_template" -m "$file" -o "$TEMP_FOLDER/transforms/${filename}" -n 20 -t 'r' > "$LOG_OUTPUT"
    antsApplyTransforms -d 3 -i "$RSS_mask" -r "$croped_template" -o "$TEMP_FOLDER/masks/${filename}.nii.gz" -t "$TEMP_FOLDER/transforms/${filename}0GenericAffine.mat" > "$LOG_OUTPUT"
    fslmaths "$TEMP_FOLDER/masks/${filename}.nii.gz" -add 0.49 "$TEMP_FOLDER/masks/${filename}.nii.gz" -odt int
done

# Multiply all obtained masks
first_image=1
common_RSS_mask="$process_dir/masks/common_RSS_mask.nii.gz"
find "$TEMP_FOLDER/masks" -type f -name "*.nii.gz" | while read image; do
    if [ $first_image -eq 1 ]; then
        cp "$image" "$common_RSS_mask"
        first_image=0
    else
        fslmaths "$common_RSS_mask" -mul "$image" "$common_RSS_mask"
    fi
done

# Multiply final mask by the template mask
template_mask_path=$(jq -r .crop_atlas.mask2crop_path config.json)
croped_mask="$process_dir/croped_template/croped_mask.nii.gz"
cp "$template_mask_path" "$croped_mask"
fslmaths "$croped_mask" -mul "$common_RSS_mask" "$croped_mask"


#Multiply all template files by the croped mask
fslmaths "$croped_template" -mul "$croped_mask" "$croped_template"

labels_path=$(jq -r .crop_atlas.labels2copy_path config.json)
croped_labels="$process_dir/croped_template/croped_labels.nii.gz"
cp "$labels_path" "$croped_labels"
fslmaths "$croped_labels" -mul "$croped_mask" "$croped_labels"

CSFmask_path=$(jq -r .crop_atlas.CSFmask2crop_path config.json)
croped_CSFmask="$process_dir/croped_template/croped_CSFmask.nii.gz"
cp "$CSFmask_path" "$croped_CSFmask"
fslmaths "$croped_labels" -mul "$croped_mask" "$croped_labels"

WMmask_path=$(jq -r .crop_atlas.WMmask2crop_path config.json)
croped_WMmask="$process_dir/croped_template/croped_WMmask.nii.gz"
cp "$WMmask_path" "$croped_WMmask"
fslmaths "$croped_WMmask" -mul "$croped_mask" "$croped_WMmask"

rm -rf "$TEMP_FOLDER"
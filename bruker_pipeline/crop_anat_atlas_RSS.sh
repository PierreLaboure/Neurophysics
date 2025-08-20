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

source "$(conda info --base)/etc/profile.d/conda.sh" > /dev/null 2>&1
conda activate stable312 > /dev/null 2>&1
crop_script="$(pwd)/crop_img2rigidReg.py"

TEMP_FOLDER=$(mktemp -d)
mkdir -p "$TEMP_FOLDER/anat_masks" "$TEMP_FOLDER/anat_transforms"
mkdir -p "$TEMP_FOLDER/R_atlas_masks" "$TEMP_FOLDER/S_atlas_masks" "$TEMP_FOLDER/R_atlas_transforms" "$TEMP_FOLDER/S_atlas_transforms"
mkdir -p "$process_dir/masks" "$process_dir/croped_template"
mkdir -p "$TEMP_FOLDER/func"

# Copying template to process dir
template_path=$(jq -r .crop_atlas.template2crop_path config.json)
template="$process_dir/croped_template/croped_template.nii.gz"
cp "$template_path" "$template"


bids_dir="$process_dir/bids"

find "$process_dir/bids" -type d -name 'sub-*' | while read dir; do
    subname=$(basename "$dir")

    sub_anat_dir="$process_dir/bids/$subname/anat"
    sub_func_dir="$process_dir/bids/$subname/func"

    anat_img=$(find "$process_dir/bids/$subname" -type f -name '*.nii.gz' \
        -exec bash -c '[[ "$(basename "$(dirname "{}")")" == "anat" ]]' \; -print | sort | head -n 1)
    func_img=$(find "$process_dir/bids/$subname" -type f -name '*.nii.gz' \
        -exec bash -c '[[ "$(basename "$(dirname "{}")")" == "func" ]]' \; -print | sort | head -n 1)


    # Register using only 1 frame of the bold scan
    filename=$(basename "$func_img" .nii.gz)

    framefunc="$TEMP_FOLDER/func/${filename}.nii.gz"
    fslroi "$func_img" "$framefunc" 10 1
    IS_crop=$(jq -r .crop_anat.IS_crop config.json)
    fslroi "$anat_img" "$anat_img" 0 -1 0 -1 $IS_crop -1

    RSS_mask="$process_dir/RSS/bold/$subname/${filename}.nii.gz"

    # BOLD 2 ANAT RIGID TRANSFORM AND MASK TRANSFORM
    antsRegistrationSyN.sh -d 3 -f "$anat_img" -m "$framefunc" -o "$TEMP_FOLDER/anat_transforms/${filename}" -n 20 -t 'r' > "$LOG_OUTPUT"
    antsApplyTransforms -d 3 -i "$RSS_mask" -r "$anat_img" -o "$TEMP_FOLDER/anat_masks/${filename}.nii.gz" -t "$TEMP_FOLDER/anat_transforms/${filename}0GenericAffine.mat" > "$LOG_OUTPUT"
    fslmaths "$TEMP_FOLDER/anat_masks/${filename}.nii.gz" -add 0.49 "$TEMP_FOLDER/anat_masks/${filename}.nii.gz" -odt 'int' > "$LOG_OUTPUT"
    
    antsRegistrationSyN.sh -d 3 -f "$template" -m "$anat_img" -o "$TEMP_FOLDER/R_atlas_transforms/${filename}" -n 20 -t 'r' > "$LOG_OUTPUT"
    python "$crop_script" -i "$TEMP_FOLDER/R_atlas_transforms/${filename}InverseWarped.nii.gz" -r "$anat_img" --inplace 1 > "$LOG_OUTPUT"

    antsRegistrationSyN.sh -d 3 -f "$TEMP_FOLDER/R_atlas_transforms/${filename}InverseWarped.nii.gz" -m "$anat_img" -o "$TEMP_FOLDER/S_atlas_transforms/${filename}" -n 20 -t 's' > "$LOG_OUTPUT"



    antsApplyTransforms -d 3 -i "$TEMP_FOLDER/anat_masks/${filename}.nii.gz" -r "$TEMP_FOLDER/R_atlas_transforms/${filename}InverseWarped.nii.gz" -o "$TEMP_FOLDER/S_atlas_masks/${filename}.nii.gz" -t "$TEMP_FOLDER/S_atlas_transforms/${filename}0GenericAffine.mat"
    antsApplyTransforms -d 3 -i "$TEMP_FOLDER/S_atlas_masks/${filename}.nii.gz" -r "$TEMP_FOLDER/R_atlas_transforms/${filename}InverseWarped.nii.gz" -o "$TEMP_FOLDER/S_atlas_masks/${filename}.nii.gz" -t "$TEMP_FOLDER/S_atlas_transforms/${filename}1Warp.nii.gz"
    antsApplyTransforms -d 3 -i "$TEMP_FOLDER/S_atlas_masks/${filename}.nii.gz" -r "$template" -o "$TEMP_FOLDER/R_atlas_masks/${filename}.nii.gz" -t "$TEMP_FOLDER/R_atlas_transforms/${filename}0GenericAffine.mat"
    fslmaths "$TEMP_FOLDER/R_atlas_masks/${filename}.nii.gz" -add 0.49 "$TEMP_FOLDER/R_atlas_masks/${filename}.nii.gz" -odt 'int' > "$LOG_OUTPUT"

    fslmaths "$anat_img" -mul "$TEMP_FOLDER/anat_masks/${filename}.nii.gz" "${anat_img}"
done


# Multiply all obtained masks
first_image=1
common_RSS_mask="$process_dir/masks/common_RSS_mask.nii.gz"
find "$TEMP_FOLDER/R_atlas_masks" -type f -name "*.nii.gz" | while read image; do
    if [ $first_image -eq 1 ]; then
        cp "$image" "$common_RSS_mask"
        first_image=0
    else
        fslmaths "$common_RSS_mask" -mul "$image" "$common_RSS_mask"
    fi
done



# Backpropagate common mask to anat and bold levels : 
mkdir -p "$TEMP_FOLDER/back_anat_mask" "$TEMP_FOLDER/back_func_mask" 

find "$TEMP_FOLDER/func" -type f -name '*.nii.gz' | while read file; do
    func_name=$(basename "$file" .nii.gz)
    subject_name="${func_name%%_task*}"

    # fetch anat
    anat_img=$(find "$process_dir/bids/$subject_name" -type f -name '*.nii.gz' \
        -exec bash -c '[[ "$(basename "$(dirname "{}")")" == "anat" ]] && echo "{}"' \; | sort | head -n 1)


    # Take the inverse of the rigid transform from anat to template

    antsApplyTransforms -d 3 -i "$common_RSS_mask" \
        -r "$anat_img" \
        -o "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" \
        -t "[${TEMP_FOLDER}/R_atlas_transforms/${func_name}0GenericAffine.mat,1]"
    

    antsApplyTransforms -d 3 -i "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" \
        -r "$anat_img" \
        -o "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" \
        -t "$TEMP_FOLDER/S_atlas_transforms/${func_name}1InverseWarp.nii.gz"

    antsApplyTransforms -d 3 -i "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" \
        -r "$anat_img" \
        -o "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" \
        -t "[${TEMP_FOLDER}/S_atlas_transforms/${func_name}0GenericAffine.mat,1]"

    fslmaths "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" -add 0.49 \
        "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" -odt int > "$LOG_OUTPUT"
    fslmaths "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" -mul "$anat_img" "$anat_img"

    # Take the inverse of the rigid transform from bold to anat
    find "$process_dir/bids/$subject_name" -type f -name '*.nii.gz' \
        -exec bash -c '[[ "$(basename "$(dirname "{}")")" == "func" ]] && echo "{}"' \; \
        | while read func_img; do

            antsApplyTransforms -d 3 -i "$TEMP_FOLDER/back_anat_mask/${func_name}.nii.gz" \
                -r "$func_img" \
                -o "$TEMP_FOLDER/back_func_mask/${func_name}.nii.gz" \
                -t "[${TEMP_FOLDER}/anat_transforms/${func_name}0GenericAffine.mat,1]"

            fslmaths "$TEMP_FOLDER/back_func_mask/${func_name}.nii.gz" -add 0.49 \
                "$TEMP_FOLDER/back_func_mask/${func_name}.nii.gz" -odt int > "$LOG_OUTPUT"
            fslmaths "$TEMP_FOLDER/back_func_mask/${func_name}.nii.gz" -mul "$func_img" "$func_img"
        done
done


# Multiply final mask by the template mask
template_mask_path=$(jq -r .crop_atlas.mask2crop_path config.json)
croped_mask="$process_dir/croped_template/croped_mask.nii.gz"
cp "$template_mask_path" "$croped_mask"
fslmaths "$croped_mask" -mul "$common_RSS_mask" "$croped_mask"


#Multiply all template files by the croped mask
fslmaths "$template" -mul "$croped_mask" "$template"

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

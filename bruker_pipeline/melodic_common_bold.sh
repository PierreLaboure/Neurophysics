#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 25/02/2025 by Pierre Labouré

# Apply Brain extraction to all commonspace Bold images from RABIES preprocessing step, multiply the masks obtained
#==============================================================================
#==============================================================================


# Function to display usage information
usage() {
    echo "Usage: $0 <input_data_dir> [-d <dimension>]"
    echo ""
    echo "Arguments:"
    echo "  input_data_dir     Mandatory argument for input directory"
    echo "Options:"
    echo "  -d, --dimension    Number of components for ICA (must be an integer)"
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (input_data_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <input_data_dir>." >&2
    usage
fi


# Assign required first argument
input_data_dir="$1"
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

# Example usage of parsed values
echo "Input Data Directory: $input_data_dir"


source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rss

# create RSS/input and RSS/masks
TEMP_FOLDER=$(mktemp -d)
mkdir -p "$TEMP_FOLDER/input" "$TEMP_FOLDER/masks"


# extract all commonspace bold (at least some repetitions, not necessarily the 400)
# cp them to RSS/input
find "$input_data_dir/preprocess/bold_datasink/commonspace_bold" -type f -name '*nii.gz' | while read file; do
    filename=$(basename "$file")
    name="${filename%%".nii.gz"}"
    cp "$file" "$TEMP_FOLDER/input/${name}_0000.nii.gz"
done
RS2_predict -i "$TEMP_FOLDER/input" -o "$TEMP_FOLDER/masks" -m "/volatile/home/pl279327/Documents/brain_extraction/Rodent-Skull-Stripping/RS2_pretrained_model.pt" -device "cpu"


# multiply all masks output
temp_file="$TEMP_FOLDER/masks/temp_multiplied_image.nii.gz"
first_image=1
find "$TEMP_FOLDER/masks" -type f -name "*.nii.gz" | while read image; do
    if [ $first_image -eq 1 ]; then
        cp "$image" "$temp_file"
        first_image=0
    else
        fslmaths "$temp_file" -mul "$image" "$temp_file"
    fi
done

mkdir -p "$input_data_dir/masks"
cp "$temp_file" "$input_data_dir/masks/melodic_mask.nii.gz"


rm -rf "$TEMP_FOLDER"
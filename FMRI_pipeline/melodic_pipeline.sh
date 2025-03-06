#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 27/01/2025 by Pierre Labouré

# Apply Brain extraction to all commonspace Bold images from RABIES preprocessing step, multiply the masks obtained and input it to melodic
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

# Default values
dimension=10  # Default ICA dimension value

# Assign required first argument
input_data_dir="$1"
shift  # Move past the first argument

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -d|--dimension)
            shift
            if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
                dimension="$1"
            else
                echo "Error: --dimension requires an integer argument." >&2
                usage
            fi
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
echo "ICA Dimension: $dimension"


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


# get maximum connex component (just in case) with python
# make a list of all confound corrected maps
mkdir -p "$input_data_dir/list"
list_path="$input_data_dir/list/listConfound.txt"
touch "$list_path"
> "$list_path"

confound_path="$input_data_dir/confound/confound_correction_datasink/cleaned_timeseries"
find "$confound_path" -type f -name '*nii.gz' | while read file; do
    realpath "$file" >> "$list_path"
done

# make dir for output
mkdir -p "$input_data_dir/melodic"
melodic -i "$input_data_dir/list/listConfound.txt" -o "$input_data_dir/melodic" -m "$input_data_dir/masks/melodic_mask.nii.gz" --report -d "$dimension" --seed=1 -v

rm -rf "$TEMP_FOLDER"
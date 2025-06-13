#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 06/03/2025 by Pierre Labouré

# Apply brain extraction on all bold scans
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
mkdir -p "$input_data_dir/RSS" "$input_data_dir/RSS/input" "$input_data_dir/RSS/masks" "$input_data_dir/RSS/bold"


# extract all input bold (at least some repetitions, not necessarily the 400)
# cp them to RSS/input

find "$input_data_dir/bids" -type f -name '*bold.nii.gz' -mindepth 2 | while read file; do
    filename=$(basename "$file" .nii.gz)
    subname="${filename%%_task*}"
    mkdir -p "$input_data_dir/RSS/bold/$subname"

    cp "$file" "$input_data_dir/RSS/input/${filename}_0000.nii.gz"
done



RS2_predict -i "$input_data_dir/RSS/input" -o "$input_data_dir/RSS/masks" -m "/volatile/home/pl279327/Documents/brain_extraction/Rodent-Skull-Stripping/RS2_pretrained_model.pt" -device "cpu"

find "$input_data_dir/RSS/masks" -type f | while read file; do
    filename=$(basename "$file" _0000.nii.gz)
    subname="${filename%%_task*}"
    cp "$file" "$input_data_dir/RSS/bold/$subname/${filename}.nii.gz"
done

rm -rf "$input_data_dir/RSS/input" "$input_data_dir/RSS/masks"

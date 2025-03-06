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


# Assign required first argument
input_data_dir="$1"
echo "Input Data Directory: $input_data_dir"
shift  # Move past the first argument

cmd="melodic -i "$input_data_dir/list/listConfound.txt" -o $input_data_dir/melodic"
if [[ -d "$input_data_dir/masks" ]]; then
    cmd+=" -m $input_data_dir/masks/melodic_mask.nii.gz"
fi

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -d|--dimension)
            shift
            if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
                echo "ICA Dimension: $1"
                cmd+=" -d $1"
            else
                echo "Error: --dimension requires an integer argument." >&2
                usage
            fi
            ;;
        -r|--report)
            cmd+=" --report"
            ;;
        -v|--verbose)
            cmd+=" --verbose"
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            ;;
    esac
    shift
done




source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rss

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
cmd+=" --seed=1"
echo -e "\n Running $cmd\n"
eval "$cmd"

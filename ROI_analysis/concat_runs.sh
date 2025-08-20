#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 10/03/2025 by Pierre Labouré

# Temporal concatenate confound corrected runs of the same subject into a single run
#==============================================================================
#==============================================================================


# Function to display usage information
usage() {
    echo "Usage: $0 <confound_data_dir> [-d <dimension>]"
    echo ""
    echo "Arguments:"
    echo "  confound_data_dir     Mandatory argument for confound directory"
    echo "Options:"
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (confound_data_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <confound_data_dir>." >&2
    usage
fi


# Assign required first argument
confound_data_dir="$1"
echo "confound Data Directory: $confound_data_dir"
shift  # Move past the first argument

if [[ -d "$confound_data_dir/masks" ]]; then
    cmd+=" -m $confound_data_dir/masks/melodic_mask.nii.gz"
fi

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
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

timeseries_data_dir="$confound_data_dir/confound_correction_datasink/cleaned_timeseries"

process_data_dir=$(dirname "$confound_data_dir")
confound_name=$(basename "$confound_data_dir")

concat_runs_dir="$process_data_dir/concat_${confound_name}/confound_correction_datasink"
mkdir -p "$concat_runs_dir"

# Find all directories, extract their base name before "_task-rest", and get unique prefixes

prefixes=$(find "$timeseries_data_dir" -mindepth 2 -maxdepth 2 -type f -wholename '*_task-rest*' | 
           awk -F'_task-rest' '{print $1$2}' | sort -u)

for prefix in $prefixes; do
    echo "Processing prefix: $prefix"
    
    # Find all directories matching this prefix
    matching_files=$(find "$timeseries_data_dir" -mindepth 2 -maxdepth 2 -type f -name "$(basename $prefix)*")

    first_image=1
     for file in $matching_files; do
        concat_run="$concat_runs_dir/$(basename $prefix)_run-00_confound_corrected.nii.gz"
        echo "  Processing file: $(basename $file)"
        if [ $first_image -eq 1 ]; then
            cp "$file" "$concat_run"
            first_image=0
        else
            fslmerge -t "$concat_run" "$concat_run" "$file"

        fi
    done
done


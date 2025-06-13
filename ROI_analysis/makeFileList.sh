#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 14/02/2025 by Pierre Labouré

# Making a list of confound files depending on groups
#==============================================================================
#==============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 <input_data_dir>"
    echo ""
    echo "Arguments:"
    echo "  confound_dir     Mandatory argument for input directory"
    echo "  type_filter        String to look for at the start of subject names to classify them"
    echo "  list_runs          List of runs that need to be isolated format '4 5'"
    echo "  out_list_name      Name of output list file"
    echo "Options:"
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (input_data_dir) is provided
if [[ $# -lt 1 ]]; then
    echo "Error: Missing mandatory argument <input_data_dir>." >&2
    usage
fi


# Assign required first argument
confound_dir="$1"
type_filter="$2"
list_runs=($3)
out_list_name="$4"
shift 4 # Move past the first argument

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
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

input_data_dir=$(dirname "$confound_dir")
confound_data_dir="$confound_dir/confound_correction_datasink"
helper_path="$input_data_dir/Helper.csv"
list_dir="$input_data_dir/list"
list_path="$input_data_dir/list/$out_list_name"
touch "$list_path"
> "$list_path"

# Read confound files
find "$confound_data_dir" -type f -name '*nii.gz' | sort | while read file; do
    #realpath "$file" >> "$list_path"
    filename=$(basename "$file")
    subjID="${filename#*"sub-"}"
    subjID="${subjID%%"_"*}"

    #Using Helper.csv, get the raw name of the corresponding subject
    rawdata=$(awk -F',' -v id="$subjID" '
        NR==1 {
            for (i=1; i<=NF; i++) {
                if ($i ~ /SubjID/) subj_col=i;
                if ($i ~ /RawData/) raw_col=i;
            }
            next;
        }
        $subj_col == id { print $raw_col; exit }
    ' "$helper_path")

    if [[ "$rawdata" == "$type_filter"* ]]; then
        run_number="${filename#*"run-"}"
        run_number="${run_number%%"_"*}"

        for filter_run in "${list_runs[@]}"; do
            formatted_run=$(printf "%02d" "$filter_run")

            if [[ "$formatted_run" == "$run_number" ]]; then
                realpath "$file" >> "$list_path"
            fi
            
        done

    fi
done
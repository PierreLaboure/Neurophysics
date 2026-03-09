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
        -r|--runs)
            list_runs=($2)
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -v|--verbose)
            cmd+=" --verbose"
            shift 1
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

# ----- new: build suffix from list_runs -----
run_suffix=""
for r in "${list_runs[@]}"; do
    printf -v r2 "%02d" "$r"
    run_suffix="${run_suffix}_${r2}"
done
# --------------------------------------------

concat_runs_dir="$process_data_dir/concat_${confound_name}${run_suffix}/confound_correction_datasink"
mkdir -p "$concat_runs_dir"

# prefixes grouped ignoring run-number
prefixes=$(find "$timeseries_data_dir" -mindepth 2 -maxdepth 2 -type f -wholename '*_task-rest*' |
           awk -F'_run-[0-9]+' '{print $1$2}' | sort -u)

for prefix in $prefixes; do
    echo "Processing prefix: $prefix"

    matching_files=$(find "$timeseries_data_dir" -mindepth 2 -maxdepth 2 -type f -name "$(basename $prefix)*" | sort)

    first_image=1
    for file in $matching_files; do

        # --- filter by run number before merging ---
        run_num="${file#*run-}"        # "03_desc-....nii.gz"
        run_num="${run_num%%_*}"       # "03"

        keep_this_run=0
        for r in "${list_runs[@]}"; do
            printf -v r2 "%02d" "$r"
            if [[ "$r2" == "$run_num" ]]; then
                keep_this_run=1
                break
            fi
        done
        [[ $keep_this_run -eq 0 ]] && continue
        # -------------------------------------------

        concat_run="$concat_runs_dir/$(basename $prefix)_run-00_confound_corrected.nii.gz"
        echo "  Merging run $run_num: $(basename $file)"
        
        if [ $first_image -eq 1 ]; then
            cp "$file" "$concat_run"
            first_image=0
        else
            fslmerge -t "$concat_run" "$concat_run" "$file"
        fi
    done
done



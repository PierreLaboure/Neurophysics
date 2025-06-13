#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 28/02/2025 by Pierre Labouré

# When dealing with T2maps with multiple echos, create a backup of the original scans before summing all the scans into a better contrast one
#==============================================================================
#==============================================================================


# Function to display usage information
usage() {
    echo "Usage: $0 <process_dir>"
    echo ""
    echo "Arguments:"
    echo "  process_dir     Mandatory argument for input processing directory containing a bids directory"
    echo "Options:"
    echo "  -v, --verbose      How much this function talks   "
    echo "  -h, --help         Show this help message and exit"
    exit 1
}

# Ensure at least one argument (bids_dir) is provided
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

# Define a function to copy anat files to backup and sum them inside of temp dir
backup_and_sum() {
    bids_dir="$1"
    backup_dir="$2"
    dir="$3"
    TEMP_dir="$4"

    temp_image="$TEMP_FOLDER/temp_multiplied_image.nii.gz"

    log "Making backup for $dir"
    mkdir -p "$backup_dir/$dir"
    find "$bids_dir/$dir/anat" -type f | while read file; do
        filename=$(basename "$file")
        cp "$file" "$backup_dir/$dir/$filename"
        rm "$file"
    done
    
    log "Summing all T2w in $dir"
    first_image=1
    find "$backup_dir/$dir" -type f -name "*.nii.gz" | while read image; do
        if [ $first_image -eq 1 ]; then
            cp "$image" "$temp_image"
            first_image=0
        else
            fslmaths "$temp_image" -add "$image" "$temp_image"
        fi
    done

    file=$(find "$backup_dir/$dir" -type f -name '*.nii.gz' | sort | head -n 1)
    filename=$(basename "$file")
    log "Creating new single anat image : $filename"
    cp "$temp_image" "$bids_dir/$dir/anat/${filename%%_*}_T2w.nii.gz"
    

}


TEMP_FOLDER=$(mktemp -d)
temp_image="$TEMP_FOLDER/temp_multiplied_image.nii.gz"

bids_dir="$process_dir/bids"

if [[ ! -d "$process_dir/backupT2map" ]];then

    backup_dir="$process_dir/backupT2map"
    mkdir -p "$backup_dir"

    find "$bids_dir" -type d -name 'sub-*' | while read dir; do
        has_ses_dirs=false
        # Look for ses-* subdirectories inside sub-*
        for ses_dir in "$dir"/ses-*; do
            if [ -d "$ses_dir" ]; then
                has_ses_dirs=true
                # Check if this ses-* dir contains both anat and func
                if [ -d "$ses_dir/anat" ] && [ -d "$ses_dir/func" ]; then
                    # Output relative path from bids_dir
                    sub_dirname="${ses_dir#$bids_dir/}"
                    backup_and_sum "$bids_dir" "$backup_dir" "$sub_dirname" "$TEMP_FOLDER"
                fi
            fi
        done

        # If no ses-* subdirs, check sub-* dir directly
        if [ "$has_ses_dirs" = false ]; then
            if [ -d "$dir/anat" ] && [ -d "$dir/func" ]; then
                sub_dirname="${dir#$bids_dir/}"
                backup_and_sum "$bids_dir" "$backup_dir" "$sub_dirname" "$TEMP_FOLDER"
            fi
        fi
    done


else
    echo "Backup and Sum already done"
fi

rm -rf "$TEMP_FOLDER"
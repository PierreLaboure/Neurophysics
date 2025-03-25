#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 21/03/2025 by Pierre Labouré

# Properly downscale the "croped_mask.nii.gz" map into RABIES commonspace dimensions
# This function uses the croped mask from "croped_template"
#==============================================================================
#==============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 <process_dir>"
    echo ""
    echo "Arguments:"
    echo "  process_dir     Mandatory argument for input processing directory which contains bids dir and rabies dirs"
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

TEMP_dir=$(mktemp -d)

croped_template_dir="$process_dir/croped_template"
croped_mask="$croped_template_dir/croped_mask.nii.gz"

downscaled_mask="$croped_template_dir/downscaled_mask.nii.gz"
commonspace_mask=$(find "$process_dir/preprocess/bold_datasink/commonspace_mask" -maxdepth 3 -type f -name '*.nii.gz' -print -quit)
echo "$commonspace_mask"

antsRegistrationSyN.sh -d 3 -f "$commonspace_mask" -m "$croped_mask" -o "$TEMP_dir/downscale" -n 20 -t 'a'
fslmaths "$TEMP_dir/downscaleWarped.nii.gz" "$downscaled_mask" -odt 'int'

rm -rf "$TEMP_FOLDER"


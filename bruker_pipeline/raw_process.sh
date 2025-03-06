#!/bin/bash

usage() {
    echo "Usage: $0 <raw_data_dir> <out_data_dir> [-d|--denoise]"
    echo "  raw_data_dir     Mandatory argument for raw directory"
    echo "  out_data_dir     Mandatory argument for output directory"
    echo "Options:"
    echo "  -d, --denoise   Enable denoising"
    echo "  -v, --verbose   How much this function talks   "
    echo "  -h, --help      Show this help message and exit"
    exit 1
}

# Check if at least two arguments are provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Default values
denoise=0
verbose=1

# Assign required arguments
raw_data_dir="$1"
out_data_dir="$2"

shift 2  # Move past the first two arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d|--denoise)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then  # Check if next argument exists and is a number
                denoise="$2"
                shift 2  # Move past both '-d' and its value
            else
                echo "Error: wrong input type for denoise : '$1'" >&2
                exit 1
            fi
            ;;
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
            exit 1
            usage
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



out_name="Helper"
if [[ $verbose == 1 ]]; then
    brkraw bids_helper "$raw_data_dir" "$out_data_dir/$out_name" -j
else
    brkraw bids_helper "$raw_data_dir" "$out_data_dir/$out_name" -j > /dev/null 2>&1
fi

filePath="$out_data_dir/${out_name}.csv"

modality_index=$(head -1 "$filePath" | awk -F, '{for (i=1; i<=NF; i++) if ($i == "modality") print i}')
type_index=$(head -1 "$filePath" | awk -F, '{for (i=1; i<=NF; i++) if ($i == "DataType") print i}')
task_index=$(head -1 "$filePath" | awk -F, '{for (i=1; i<=NF; i++) if ($i == "task") print i}')

####################################################################################################################################################
###process bids_helper
#Keep only scans which are anat or func in the DataType colunm
/usr/bin/awk -F, -v type_idx="$type_index" '(FNR==1||$6=="func"||$(type_idx)=="anat") {print}' "$filePath" |\
#Remove content of colunm 3
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {if (NR>1) {$3=""}} { print }'|\
#Write "bold" and "T2w" in modality for "func" and "anat" rows respectively
/usr/bin/awk -F, -v modality_idx="$modality_index" -v type_idx="$type_index" 'BEGIN{FS = OFS = ","} {if ($(type_idx)=="func") {$(modality_idx)="bold"} if ($(type_idx)=="anat") {$(modality_idx)="T2w"} print }' |\
#Write "rest" as task for "bold" rows
/usr/bin/awk -F, -v task_idx="$task_index" -v type_idx="$type_index" 'BEGIN{FS = OFS = ","} {if ($(type_idx)=="func") {$(task_idx)="rest"} print }' |\
#Remove string "Underscore" from subjID names
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {gsub(/Underscore/,"",$2)} { print }' > tmp && mv tmp $filePath

#removing useless scans
source "$(conda info --base)/etc/profile.d/conda.sh" > "$LOG_OUTPUT"
conda activate stable312 > "$LOG_OUTPUT"
python clean_scans.py "$filePath" "$out_data_dir/Scans.xlsx" -d $denoise > $LOG_OUTPUT

#converting to bids
if [[ $verbose == 1 ]]; then    
    brkraw bids_convert "$raw_data_dir" "$out_data_dir/$out_name.csv" -j "$out_data_dir/$out_name.json" -o "$out_data_dir/bids"
else
    brkraw bids_convert "$raw_data_dir" "$out_data_dir/$out_name.csv" -j "$out_data_dir/$out_name.json" -o "$out_data_dir/bids" > /dev/null 2>&1
fi


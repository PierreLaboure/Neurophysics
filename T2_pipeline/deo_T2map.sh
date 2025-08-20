#!/bin/bash


usage() {
    echo "Usage: $0 <bids_dir>"
    echo "  bids_dir     Mandatory argument for bids directory"
    echo "Options:"
    echo "  -v, --verbose   How much this function talks   "
    echo "  -h, --help      Show this help message and exit"
    exit 1
}

# Check if at least one arguments is provided
if [ "$#" -lt 0 ]; then
    usage
fi

#default values
verbose=1

#Assign required arguments
raw_data_dir=$(jq -r .raw_data_dir config.json)
process_dir=$(jq -r .process_data_dir config.json)
 
#shift 2
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

IS_crop=$(jq -r .IS_crop config.json)

find "$raw_data_dir" -mindepth 1 -maxdepth 1 | while read dir; do
    T2map=$(find "$dir" -type f -name '*_3.nii' | awk -F/ -v base="$dir" '
    {
        sub(base "/?", "", $0);                   # Remove base path
        match($0, /^[0-9]+/);                      # Match numeric directory
        if (RSTART > 0) {
            dirnum = substr($0, RSTART, RLENGTH);  # Extract numeric part
            print dirnum ":" base "/" $0;
        }
    }' | sort -t: -k1,1nr | head -n1 | cut -d: -f2)
    file="$T2map"
    echo "$file"

    dirname="$(dirname $file)"
    extracted="${dirname#*raw/}"
    subject_name="${extracted%%/*}"


    X=${subject_name%_*}
    Y=${subject_name##*_}
    X=$(echo "$X" | grep -oE '[0-9]+')

    if [[ "$Y" == "after" && "$X" == "668" ]]; then
        X="6698"
    fi

    anat=$(find "$process_dir/bids" -type f -name "*$X*" -name "*rs$Y*" -name "*T2w.nii.gz")

    rm -f "$dirname/T2map.nii.gz"
    3dWarp -oblique2card -prefix "$dirname/T2map.nii.gz" "$file" > "$LOG_OUTPUT"
    fslswapdim "$dirname/T2map.nii.gz" -x -z -y "$dirname/T2map.nii.gz"
    fslorient -forceradiological "$dirname/T2map.nii.gz"
    fslroi "$dirname/T2map.nii.gz" "$dirname/T2map.nii.gz" 0 -1 0 -1 $IS_crop -1
    bash reorient_anat.sh "$anat" "$dirname/T2map.nii.gz" 0
done
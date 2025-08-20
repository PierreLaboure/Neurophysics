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
process_data_dir=$(jq -r .process_data_dir config.json)

mkdir -p "$process_data_dir/commonspace_T2map"

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

transforms_datasink="$process_data_dir/preprocess/transforms_datasink"

unbiased2atlas_affine="$process_data_dir/preprocess/transforms_datasink/unbiased_to_atlas_affine/template_sharpen_shapeupdate_output_0GenericAffine.mat"
unbiased2atlas_warp="$process_data_dir/preprocess/transforms_datasink/unbiased_to_atlas_warp/template_sharpen_shapeupdate_output_1Warp.nii.gz"

unbiased="$process_data_dir/preprocess/unbiased_template_datasink/unbiased_template/template_sharpen_shapeupdate.nii.gz"
commonspace_labels=$(find "$process_data_dir/preprocess/bold_datasink/commonspace_labels" -type f | head -n 1 )
template="$process_data_dir/croped_template/croped_template.nii.gz"


find "$raw_data_dir" -type f -name '*T2map.nii.gz' | while read file; do
    dirname="$(dirname $file)"
    extracted="${dirname#*raw/}"
    subject_name="${extracted%%/*}"

    echo "processing $subject_name"


    X=${subject_name%_*}
    Y=${subject_name##*_}
    X=$(echo "$X" | grep -oE '[0-9]+')

    if [[ "$Y" == "after" && "$X" == "668" ]]; then
        X="6698"
    fi

    native2unbiased_affine=$(find "$transforms_datasink/native_to_unbiased_affine" -type f -name "*$X*" -name "*rs$Y*")
    native2unbiased_warp=$(find "$transforms_datasink/native_to_unbiased_warp" -type f -name "*$X*" -name "*rs$Y*")


    #anat 2 unbiased transforms

    antsApplyTransforms -d 3 -i "$file" -r "$unbiased" -o "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -t "$native2unbiased_affine" > "$LOG_OUTPUT"
    if [[ -n "$native2unbiased_warp" ]]; then
        antsApplyTransforms -d 3 -i "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -r "$unbiased" -o "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -t "$native2unbiased_warp" > "$LOG_OUTPUT"
    fi

    #unbiased 2 commonspace transforms
    #antsApplyTransforms -d 3 -i "$dirname/temp.nii.gz" -r "$commonspace_labels" -o "$dirname/temp.nii.gz" -t "$unbiased2atlas_affine" > "$LOG_OUTPUT"
    antsApplyTransforms -d 3 -i "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -r "$template" -o "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -t "$unbiased2atlas_affine" > "$LOG_OUTPUT"
    if [[ -f "$unbiased2atlas_warp" ]]; then
        #antsApplyTransforms -d 3 -i "$dirname/temp.nii.gz" -r "$commonspace_labels" -o "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -t "$unbiased2atlas_warp" > "$LOG_OUTPUT"
        antsApplyTransforms -d 3 -i "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -r "$template" -o "$process_data_dir/commonspace_T2map/${X}_${Y}_commonspace_anat.nii.gz" -t "$unbiased2atlas_warp" > "$LOG_OUTPUT"
    fi

done
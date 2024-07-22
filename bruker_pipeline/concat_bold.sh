#!/bin/bash

bids_dir="$1"

for func_dir in "$bids_dir"/sub*/func/; do

    files=$(find "$func_dir" -type f -name "*.nii.gz")
    IFS=$'\n' read -r -d '' -a file_array <<< "$files"

    first_file="${file_array[0]}"
    new_name=$(echo "$first_file" | sed 's/_run-0[0-9]//')
    echo "Concatenating $func_dir"
    fslmerge -t "$new_name" "${file_array[@]}"

    for file in "${file_array[@]}"; do
        rm "$file"
        
    done

done

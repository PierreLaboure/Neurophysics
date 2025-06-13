#!/bin/bash

concater() {
    func_dir="$1"
    files=$(find "$func_dir" -type f -name "*.nii.gz")
    IFS=$'\n' read -r -d '' -a file_array <<< "$files"

    first_file="${file_array[0]}"
    new_name=$(echo "$first_file" | sed 's/_run-0[0-9]//')
    echo "Concatenating $func_dir"
    fslmerge -t "$new_name" "${file_array[@]}"

    for file in "${file_array[@]}"; do
        rm "$file"
        
    done

}


bids_dir="$1"

find "$bids_dir" -type d -name 'sub-*' | while read dir; do
    has_ses_dirs=false
    # Look for ses-* subdirectories inside sub-*
    for ses_dir in "$dir"/ses-*; do
        if [ -d "$ses_dir" ]; then
            has_ses_dirs=true
            # Check if this ses-* dir contains both anat and func
            if [ -d "$ses_dir/anat" ] && [ -d "$ses_dir/func" ]; then
                # Output relative path from bids_dir
                ## sub_dirname="${ses_dir#$bids_dir/}"
                echo "Concatenating bold runs in $ses_dir/func"
                func_dir="$ses_dir/func"
                concater "$func_dir"
            fi
        fi
    done

    # If no ses-* subdirs, check sub-* dir directly
    if [ "$has_ses_dirs" = false ]; then
        if [ -d "$dir/anat" ] && [ -d "$dir/func" ]; then
            ## sub_dirname="${dir#$bids_dir/}"
            echo "Concatenating bold runs in $dir/func"
            func_dir="$dir/func"
            concater "$func_dir"
        fi
    fi
done



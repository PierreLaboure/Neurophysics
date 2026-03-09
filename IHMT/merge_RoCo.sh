#!/usr/bin/env bash


config_json="$1"
process_dir=$(jq -r .process_dir "$config_json")


command -v fslmerge >/dev/null 2>&1 || { echo "fslmerge not found. Is FSL loaded?"; exit 1; }

base_dir="$process_dir/data"

for type_dir in "$base_dir"/*; do
    [ -d "$type_dir" ] || continue
    type_name=$(basename "$type_dir")

    for modality_dir in "$type_dir"/*; do
        [ -d "$modality_dir" ] || continue
        modality_name=$(basename "$modality_dir")

        for subj_dir in "$modality_dir"/*; do
            [ -d "$subj_dir" ] || continue
            subj_name=$(basename "$subj_dir")

            echo "Processing $type_name / $modality_name / $subj_name"

            cd "$subj_dir" || continue

            # Find all unique subtypes (e.g., M0, ihMTr, T2, Guiding, anat)
            subtypes=$(ls *_*_[0-9]*.nii.gz 2>/dev/null | \
                       sed -E 's/.*_([A-Za-z0-9]+)_[0-9]+\.nii\.gz/\1/' | sort -u)

            for subtype in $subtypes; do
                # List files for this subtype in descending rank
                files=$(ls *_"${subtype}"_[0-9]*.nii.gz 2>/dev/null | \
                        sed -E "s/.*_${subtype}_([0-9]+)\.nii\.gz/\1 &/" | \
                        sort -nr | cut -d' ' -f2-)

                [ -z "$files" ] && continue

                merged_file="${subj_name}_${subtype}.nii.gz"
                echo "  Merging $subtype (descending rank) -> $merged_file"
                fslmerge -y "$merged_file" $files

                if [ $? -eq 0 ]; then
                    echo "  Merge successful — removing ranked $subtype files"
                    rm -f *_"${subtype}"_[0-9]*.nii.gz
                else
                    echo "  Merge FAILED — NOT deleting files"
                fi
            done

            cd - >/dev/null || exit
        done
    done
done

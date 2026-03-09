#!/bin/bash
config_json="$1"

source lib_subjects.sh
load_subjects "$config_json"

subject_info_json=$(jq -r .subject_info "$config_json")
process_dir=$(jq -r .process_dir "$config_json")

process_data_dir="$process_dir/data"
process_RSS_dir="$process_dir/RSS"

mkdir -p "$process_RSS_dir"

for type_dir in "$process_data_dir"/*; do
    [ -d "$type_dir" ] || continue
    type_name=$(basename "$type_dir")

    for modality_dir in "$type_dir"/*; do
        [ -d "$modality_dir" ] || continue
        modality_name=$(basename "$modality_dir")

        for subj_dir in "$modality_dir"/*; do
            [ -d "$subj_dir" ] || continue
            subject_name=$(basename "$subj_dir")

            # Only process selected subjects
            if [[ ! " ${subjects_list[@]} " =~ " ${subject_name} " ]]; then
                continue
            fi

            # 🔹 Get guiding subtypes for this subject + modality
            guiding_subtypes=$(jq -r \
                --arg s "$subject_name" \
                --arg m "$modality_name" \
                '.[$s].modalities[$m].guiding[]? // empty' \
                "$subject_info_json")

            # If no guiding subtype defined → skip
            [ -z "$guiding_subtypes" ] && continue

            input_dir="$process_RSS_dir/$type_name/$modality_name/$subject_name/input"
            masks_dir="$process_RSS_dir/$type_name/$modality_name/$subject_name/masks"
            mkdir -p "$input_dir" "$masks_dir"

            # 🔹 Copy only guiding subtype files
            for subtype in $guiding_subtypes; do

                for img_file in "$subj_dir"/*_"$subtype"_*.nii* "$subj_dir"/*_"$subtype".nii*; do
                    [ -f "$img_file" ] || continue

                    base_name=$(basename "$img_file")

                    # Handle .nii.gz properly
                    if [[ "$base_name" == *.nii.gz ]]; then
                        name_only="${base_name%.nii.gz}"
                        ext="nii.gz"
                    else
                        name_only="${base_name%.nii}"
                        ext="nii"
                    fi

                    dest_file="$input_dir/${name_only}_0000.$ext"

                    cp "$img_file" "$dest_file"
                    echo "Copied (guiding subtype: $subtype): $dest_file"
                done
            done
        done
    done
done

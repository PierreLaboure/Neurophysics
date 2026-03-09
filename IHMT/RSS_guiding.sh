#!/usr/bin/env bash
config_json="$1"

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rss

source lib_subjects.sh
subject_info_json=$(jq -r .subject_info "$config_json")
load_subjects "$config_json"

process_dir=$(jq -r .process_dir "$config_json")
weights_path=$(jq -r .pretrained_weights_path "$config_json")

RSS_dir="$process_dir/RSS"

if [ ! -d "$RSS_dir" ]; then
    echo "RSS directory not found."
    exit 1
fi

command -v RS2_predict >/dev/null 2>&1 || { echo "RS2_predict not found."; exit 1; }
command -v fslmaths >/dev/null 2>&1 || { echo "fslmaths not found."; exit 1; }

for type_dir in "$RSS_dir"/*; do
    [ -d "$type_dir" ] || continue
    type_name=$(basename "$type_dir")

    for modality_dir in "$type_dir"/*; do
        [ -d "$modality_dir" ] || continue
        modality_name=$(basename "$modality_dir")

        for subj_dir in "$modality_dir"/*; do
            [ -d "$subj_dir" ] || continue
            subj_name=$(basename "$subj_dir")

            # Only process selected subjects
            if [[ ! " ${subjects_list[@]} " =~ " ${subj_name} " ]]; then
                continue
            fi

            input_dir="$subj_dir/input"
            masks_dir="$subj_dir/masks"

            [ -d "$input_dir" ] || continue

            echo "Running RSS on: $type_name / $modality_name / $subj_name"

            # -------------------------
            # 1️⃣ Run RSS prediction
            # -------------------------
            RS2_predict \
                -i "$input_dir" \
                -o "$masks_dir" \
                -m "$weights_path" \
                -device cpu

            if [ $? -ne 0 ]; then
                echo "RSS failed for $subj_name — skipping masking"
                continue
            fi

            # -------------------------
            # 2️⃣ Apply mask
            # -------------------------
            for img in "$input_dir"/*.nii*; do
                [ -f "$img" ] || continue

                base=$(basename "$img")

                # remove _0000 before extension
                if [[ "$base" == *.nii.gz ]]; then
                    core="${base%.nii.gz}"
                    core="${core%_0000}"
                    mask_file="$masks_dir/${base%.nii.gz}.nii.gz"
                    output_file="$subj_dir/${core}.nii.gz"
                else
                    core="${base%.nii}"
                    core="${core%_0000}"
                    mask_file="$masks_dir/${base%.nii}.nii"
                    output_file="$subj_dir/${core}.nii"
                fi

                if [ ! -f "$mask_file" ]; then
                    echo "Mask not found for $base"
                    continue
                fi

                fslmaths "$img" -mul "$mask_file" "$output_file"

                if [ $? -eq 0 ]; then
                    echo "Created skull-stripped: $output_file"
                else
                    echo "Mask multiplication failed for $base"
                fi
            done

            # -------------------------
            # 3️⃣ Optional cleanup
            # -------------------------
            echo "Cleaning input directory..."
            rm -rf "$input_dir"

        done
    done
done

echo "RSS processing complete."

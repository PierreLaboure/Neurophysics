#!/usr/bin/env bash

config_json="$1"

source lib_subjects.sh
subject_info_json=$(jq -r .subject_info "$config_json")
load_subjects "$config_json"


process_dir=$(jq -r .process_dir "$config_json")
atlas_labels_path=$(jq -r .atlas_labels_path "$config_json")

core_template="$process_dir/atlas/core_template.nii.gz"
RSS_dir="$process_dir/RSS"

warp_base="$process_dir/transforms/Warp"
registered_base="$process_dir/transforms/Registered"

mkdir -p "$warp_base"
mkdir -p "$registered_base"

command -v antsRegistrationSyN.sh >/dev/null 2>&1 || { echo "ANTs not found."; exit 1; }
command -v antsApplyTransforms >/dev/null 2>&1 || { echo "antsApplyTransforms not found."; exit 1; }

n_process=$(jq -r .Registration.n_process "$config_json")
quick=$(jq -r .Registration.quick "$config_json")
verbose=$(jq -r .Registration.verbose "$config_json")

for type_dir in "$RSS_dir"/*; do
    [ -d "$type_dir" ] || continue
    type_name=$(basename "$type_dir")

    for modality_dir in "$type_dir"/*; do
        [ -d "$modality_dir" ] || continue
        modality_name=$(basename "$modality_dir")

        for subj_dir in "$modality_dir"/*; do
            [ -d "$subj_dir" ] || continue
            echo "${subjects_list[@]}"
            subj_name=$(basename "$subj_dir")
            echo "$subj_name"

            # Only process selected subjects
            if [[ ! " ${subjects_list[@]} " =~ " ${subj_name} " ]]; then
                continue
            fi

            core_guiding=$(find "$subj_dir" -maxdepth 1 -type f -name "*.nii.gz")
            [ -f "$core_guiding" ] || continue

            echo "Registering template → $type_name / $modality_name / $subj_name"

            warp_dir="$warp_base/$type_name/$modality_name/$subj_name"
            registered_dir="$registered_base/$type_name/$modality_name/$subj_name"

            mkdir -p "$warp_dir"
            mkdir -p "$registered_dir"

            transform_prefix="$warp_dir/${subj_name}_"

            # ------------------------------------------------
            # 1️⃣ Compute transforms (template → subject)
            # ------------------------------------------------
            if [ "$quick" -eq 1 ]; then
                antsRegistration \
                --dimensionality 3 \
                --float 0 \
                --output ["$transform_prefix","${transform_prefix}Warped.nii.gz"] \
                --interpolation Linear \
                --use-histogram-matching 1 \
                --initial-moving-transform ["$core_guiding","$core_template",1] \
                \
                --transform Rigid[0.1] \
                --metric MI["$core_guiding","$core_template",1,32,Regular,0.25] \
                --convergence [1000x500x250,1e-6,10] \
                --shrink-factors 4x2x1 \
                --smoothing-sigmas 2x1x0vox \
                \
                --transform Affine[0.1] \
                --metric MI["$core_guiding","$core_template",1,32,Regular,0.25] \
                --convergence [1000x500x250,1e-6,10] \
                --shrink-factors 4x2x1 \
                --smoothing-sigmas 2x1x0vox \
                \
                --transform SyN[0.1,3,0] \
                --metric CC["$core_guiding","$core_template",1,4] \
                --convergence [100x70x50,1e-6,10] \
                --shrink-factors 4x2x1 \
                --smoothing-sigmas 2x1x0vox \
                --verbose 1
            else
                antsRegistration \
                --dimensionality 3 \
                --float 0 \
                --output ["$transform_prefix","${transform_prefix}Warped.nii.gz","${transform_prefix}InverseWarped.nii.gz"] \
                --interpolation Linear \
                --use-histogram-matching 1 \
                --initial-moving-transform ["$core_guiding","$core_template",1] \
                \
                --transform Rigid[0.05] \
                --metric MI["$core_guiding","$core_template",1,64,Regular,0.3] \
                --convergence [2000x1000x500x250,1e-7,15] \
                --shrink-factors 6x4x2x1 \
                --smoothing-sigmas 3x2x1x0vox \
                \
                --transform Affine[0.05] \
                --metric MI["$core_guiding","$core_template",1,64,Regular,0.3] \
                --convergence [2000x1000x500x250,1e-7,15] \
                --shrink-factors 6x4x2x1 \
                --smoothing-sigmas 3x2x1x0vox \
                \
                --transform SyN[0.08,3,0] \
                --metric CC["$core_guiding","$core_template",1,4] \
                --convergence [200x100x70x50,1e-6,10] \
                --shrink-factors 6x4x2x1 \
                --smoothing-sigmas 3x2x1x0vox \
                --verbose 1

            fi

            if [ $? -ne 0 ]; then
                echo "Registration failed for $subj_name"
                continue
            fi

            affine_transform="${transform_prefix}0GenericAffine.mat"
            warp_transform="${transform_prefix}1Warp.nii.gz"

            # ------------------------------------------------
            # 2️⃣ Apply transforms to atlas labels
            # ------------------------------------------------
            registered_atlas="$registered_dir/${subj_name}_atlas_labels.nii.gz"

            antsApplyTransforms \
                -d 3 \
                -i "$atlas_labels_path" \
                -r "$core_guiding" \
                -o "$registered_atlas" \
                -t "$warp_transform" \
                -t "$affine_transform" \
                -n NearestNeighbor \
                -v "$verbose"

            if [ $? -eq 0 ]; then
                echo "Atlas registered: $registered_atlas"
            else
                echo "Atlas transform failed for $subj_name"
            fi

        done
    done
done

echo "Registration pipeline complete."
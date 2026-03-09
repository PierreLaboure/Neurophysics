#!/bin/bash

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rss
config_json="$1"

atlas_average_path=$(jq -r .atlas_average_path "$config_json")
atlas_labels_path=$(jq -r .atlas_labels_path "$config_json")
ROI_index_path=$(jq -r .ROI_index_list "$config_json")
process_dir=$(jq -r .process_dir "$config_json")

atlas_process_dir="$process_dir/atlas"
mkdir -p "$atlas_process_dir/input" "$atlas_process_dir/masks"

cp "$atlas_average_path" "$atlas_process_dir"
cp "$atlas_labels_path" "$atlas_process_dir"
cp "$ROI_index_path" "$atlas_process_dir"

RSS_input_atlas_path="$atlas_process_dir/input/atlas_0000.nii.gz"


cp $atlas_average_path $RSS_input_atlas_path
#fslroi "$RSS_input_atlas_path" "$RSS_input_atlas_path" 0 -1 43 -1 0 -1
RS2_predict -i "$atlas_process_dir/input" -o "$atlas_process_dir/masks" -m $(jq -r .pretrained_weights_path "$config_json") -device "cpu"

#Get skull stripped Atlas Average
fslmaths "$RSS_input_atlas_path" -mul "$atlas_process_dir/masks/atlas_0000.nii.gz" "$atlas_process_dir/core_template.nii.gz"
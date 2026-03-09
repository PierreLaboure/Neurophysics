#!/usr/bin/env bash
config_json="$1"

source lib_subjects.sh
subject_info_json=$(jq -r .subject_info "$config_json")
load_subjects "$config_json"

source "$(conda info --base)/etc/profile.d/conda.sh" > /dev/null 2>&1
conda activate stable312 > /dev/null 2>&1

config_json="$config_json"

process_dir=$(jq -r .process_dir "$config_json")

python extract_metrics.py \
    --process-dir "$process_dir" \
    --config "$config_json" \
    --subject-info "$subject_info_json" \
    --subjects "${subjects_list[@]}" \
    --verbose


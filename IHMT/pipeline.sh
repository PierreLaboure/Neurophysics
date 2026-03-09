#!/bin/bash

config_json="$1"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <config_json>"
    exit 1
fi



if [[ $(jq -r .fetch_data "$config_json") == 1 ]]; then
    echo "Running Fetch Data"
    bash fetch_ihMT.sh "$config_json"
fi

if [[ $(jq -r .reorient_to_standard "$config_json") == 1 ]]; then
    echo "Running Reorient to standard"
    bash reorient_to_standard.sh "$config_json"
fi

if [[ $(jq -r .merge_RoCo "$config_json") == 1 ]]; then
    echo "Running Merge Rostro-Caudal"
    bash merge_RoCo.sh "$config_json"
fi

if [[ $(jq -r .RSS_atlas "$config_json") == 1 ]]; then
    echo "Running RSS atlas"
    bash RSS_atlas.sh "$config_json"
fi

if [[ $(jq -r .copy_guiding "$config_json") == 1 ]]; then
    echo "Running Copy guiding images"
    bash copy_guiding.sh "$config_json"
fi

if [[ $(jq -r .RSS_guiding "$config_json") == 1 ]]; then
    echo "Running RSS guiding images"
    bash RSS_guiding.sh "$config_json"
fi

if [[ $(jq -r .Registration.register "$config_json") == 1 ]]; then
    echo "Running Registration of atlas to modality spaces"
    bash register_atlas_to_guiding.sh "$config_json"
fi

if [[ $(jq -r .normalization.run "$config_json") == 1 ]]; then
    echo "Running normalization of metric blocks"
    bash launch_norm.sh "$config_json"
fi

if [[ $(jq -r .extraction.run "$config_json") == 1 ]]; then
    echo "Running extraction of metrics"
    bash launch_extract.sh "$config_json"
fi

echo "Done"
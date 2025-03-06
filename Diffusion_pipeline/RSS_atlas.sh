#!/bin/bash

input_atlas="$1"
output_gzip_path="$2"
input_path="$3"
output_path="$4"
pretrained_path="$5"

gzip -c input_atlas > output_gzip_path


mv output_gzip_path "atlas_0000.nii.gz"

conda activate rss
RS2_predict -i input_path -o 'path/to/output' -m 'path/to/pretrained_model.pt'

mv "atlas_0000.nii.gz" output_gzip_path
mv output_RSS_atlas "atlas_mask.nii.gz"





#!/bin/bash

raw_data_dir="$1"
out_data_dir="$2"
out_name="Helper"

brkraw bids_helper "$raw_data_dir" "$out_data_dir/$out_name" -j

#mv -v "$out_data_dir/${out_name::-1}.json" "$out_data_dir/${out_name}.json"

filePath="$out_data_dir/${out_name}.csv"

modality_index=$(head -1 "$filePath" | awk -F, '{for (i=1; i<=NF; i++) if ($i == "modality") print i}')
type_index=$(head -1 "$filePath" | awk -F, '{for (i=1; i<=NF; i++) if ($i == "DataType") print i}')
task_index=$(head -1 "$filePath" | awk -F, '{for (i=1; i<=NF; i++) if ($i == "task") print i}')

#process bids_helper
/usr/bin/awk -F, -v type_idx="$type_index" '(FNR==1||$6=="func"||$(type_idx)=="anat") {print}' "$filePath" |\
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {if (NR>1) {$3=""}} { print }'|\
/usr/bin/awk -F, -v modality_idx="$modality_index" -v type_idx="$type_index" 'BEGIN{FS = OFS = ","} {if ($(type_idx)=="func") {$(modality_idx)="bold"} if ($(type_idx)=="anat") {$(modality_idx)="T2w"} print }' |\
/usr/bin/awk -F, -v task_idx="$task_index" -v type_idx="$type_index" 'BEGIN{FS = OFS = ","} {if ($(type_idx)=="func") {$(task_idx)="rest"} print }' |\
/usr/bin/awk -F, 'BEGIN{FS = OFS = ","} {gsub(/Underscore/,"",$2)} { print }' > tmp && mv tmp $filePath

#removing useless scans
source /home/rgolgolab/anaconda3/bin/activate
python clean_scans.py "$filePath" "$out_data_dir/Scans.xlsx"

#converting to bids
brkraw bids_convert "$raw_data_dir" "$out_data_dir/$out_name.csv" -j "$out_data_dir/$out_name.json" -o "$out_data_dir/bids"


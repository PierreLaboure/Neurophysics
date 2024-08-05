#!/bin/bash

#out_data_dir must contain a file called Scans.xlsx

insert_deo() {
	local input_string="$1"
	if [[ "$input_string" == *_bold.nii.gz ]]; then
		echo "${input_string/_bold.nii.gz/_deoblique_bold.nii.gz}"
	elif [[ "$input_string" == *T2w.nii.gz ]]; then
		echo "${input_string/_T2w.nii.gz/_deoblique_T2w.nii.gz}"
	else
		echo "$input_string"
	fi
}

insert_bold() {
    	local input_string="$1"
    	if [[ ! "$input_string" =~ _bold\.nii\.gz$ ]]; then
        	echo "${input_string%.nii.gz}_bold.nii.gz"
    	else
        	echo "$input_string"
    	fi
}

insert_T2w() {
    	local input_string="$1"
    	if [[ ! "$input_string" =~ _T2w\.nii\.gz$ ]]; then
        	echo "${input_string%.nii.gz}_T2w.nii.gz"
    	else
        	echo "$input_string"
    	fi
}

usage() {
    echo "Usage: $0 <raw_dir> <out_dir> [-c]"
    echo "  raw_data_dir     Mandatory argument for raw directory"
    echo "  out_data_dir     Mandatory argument for output directory"
    echo "  -c          Optional boolean flag for concatenation"
    exit 1
}

concat=false

# Check the number of arguments
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Error: Invalid number of arguments." >&2
    usage
fi

# Check if the last argument is '-c'
if [ "$#" -eq 3 ]; then
    if [ "$3" == "-c" ]; then
        concat=true
        raw_data_dir="$1"
        out_data_dir="$2"
    else
        echo "Error: Invalid option. The only valid optional argument is '-c' and it must be the last argument." >&2
        usage
    fi
else
    raw_data_dir="$1"
    out_data_dir="$2"
fi

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

bids_dir="$out_data_dir/bids"

# Loop through each subject directory
for subject_dir in "$bids_dir"/sub*/; do
    # Inside each subject directory
    echo "Processing $subject_dir"

    # Define the path to the func directory
    func_dir="${subject_dir}func/"

    # Check if the func directory exists
    if [ -d "$func_dir" ]; then
        # Find the .nii.gz files in the func directory ending with _EPI, _bold, or _T2w
        files=$(find "$func_dir" -type f \( -name "*.nii.gz"  \))

        # Process each found file
        for file in $files; do
            echo "Found file: $file"
            bold_file=$(insert_bold "$file")
            # deo_name=$(insert_deo "$bold_file")
            deo_name="$bold_file"
            3dTshift -prefix "$func_dir/temp.nii.gz" -tpattern altminus "$file"
            rm "$file"
            3dWarp -oblique2card -prefix "$deo_name" "$func_dir/temp.nii.gz"
        rm "$func_dir/temp.nii.gz"
        done
    else
        echo "Directory $func_dir does not exist"
    fi

    anat_dir="${subject_dir}anat/"

    #check if anat directory exists
    if [ -d "$anat_dir" ]; then
	files=$(find "$anat_dir" -type f \( -name "*.nii.gz"  \))

	#¶rocess files found
	for file in $files; do
	   echo "found file : $file"
       T2w_file=$(insert_T2w "$file")
	   #deo_name=$(insert_deo "$T2w_file")
       deo_name="$T2w_file"
           3dWarp -oblique2card -prefix "$anat_dir/temp.nii.gz" "$file"
	   rm "$file"
       mv "$anat_dir/temp.nii.gz" "$deo_name"

	done
    else
	echo "Directory $anat_dir does not exist"
    fi

done

if $concat; then
    bash concat_bold.sh "$bids_dir"
fi
mkdir "$out_data_dir/preprocess"
mkdir "$out_data_dir/confound"
mkdir "$out_data_dir/analysis"


#singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess rabies-0.4.7.simg -p MultiProc preprocess /bids /preprocess --apply_STC --TR 1.5
#singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess -B $out_data_dir/confound:/confound rabies-0.4.7.simg confound_correction /preprocess /confound --highpass 0.01 --smoothing_filter 0.35 --lowpass 0.1 --conf_list WM_signal CSF_signal mot_6
#singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess -B $out_data_dir/confound:/confound -B $out_data_dir/analysis:/analysis rabies-0.4.7.simg analysis /confound /analysis --group_ica apply=true,dim=10,random_seed=1 --FC_matrix

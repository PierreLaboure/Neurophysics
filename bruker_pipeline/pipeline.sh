#!/bin/bash

#out_data_dir must contain a file called Scans.xlsx

usage() {
    echo "Usage: $0 <out_data_dir>"
    echo "  out_data_dir     Mandatory argument for output directory"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    exit 1
}

# Check if at least two arguments are provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Default values
raw_data_dir=$(jq -r .raw_data_dir config.json)

# Assign required arguments
out_data_dir="$1"
shift   # Move past the first argument

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            ;;
    esac
    shift  # Move to the next argument
done

out_name="Helper"

####################################################################################################################################################
#Convert raw scans to bids format

if [[ $(jq -r .raw2bids.convert config.json) == 1 ]]; then
    echo "Converting raw data from $raw_data_dir to bids format, verbose $(jq -r .raw2bids.verbose config.json)"
    bash raw_process.sh "$raw_data_dir" "$out_data_dir" -d $(jq -r .raw2bids.denoise config.json) -v $(jq -r .raw2bids.verbose config.json)
fi

bids_dir="$out_data_dir/bids"


####################################################################################################################################################
#Deoblique Bold scans

if [[ $(jq -r .nifti2deoblique.deoblique config.json) == 1 ]]; then
    echo "Applying deoblique to $bids_dir"
    bash nii2deo.sh "$bids_dir" --verbose $(jq -r .nifti2deoblique.verbose config.json)
fi

####################################################################################################################################################
#Concatenating Bold Runs

if [[ $(jq -r .concat_bold_runs config.json) == 1 ]]; then
    echo "Concatenating bold runs"
    bash concat_bold.sh "$bids_dir"
fi

####################################################################################################################################################
#Identifying scans for topup correction

if [[ $(jq -r .extract_topup config.json) == 1 ]]; then
    echo "Identifying topup scans in $out_data_dir"
    bash extract_topup.sh "$raw_data_dir" "$out_data_dir"
else
    #rm topup
    z=1
fi

####################################################################################################################################################
#Applying topup correction

if [[ $(jq -r .topup.correct config.json) == 1 ]]; then
    #Need to check if topup extraction has been done
    bash topup_functional.sh "$bids_dir" "$(jq -r .topup.acqparams_path config.json)" --verbose $(jq -r .topup.verbose config.json)
fi

####################################################################################################################################################
#Making backup and summing T2maps

if [[ $(jq -r .backup_sum_anat.do config.json) == 1 ]]; then
    bash backup_sum_anat.sh "$out_data_dir" --verbose $(jq -r .backup_sum_anat.verbose config.json)
fi

####################################################################################################################################################
#Croping anatomical scans

if [[ $(jq -r .crop_anat.crop config.json) == 1 ]]; then
    bash crop_anat.sh "$bids_dir" --verbose $(jq -r .crop_anat.verbose config.json)
fi

####################################################################################################################################################
#Croping Atlas components

if [[ $(jq -r .crop_atlas.crop config.json) == 1 ]]; then
    mkdir -p "$out_data_dir/croped_template"
    bash crop_atlas.sh "$out_data_dir" --verbose $(jq -r .crop_atlas.verbose config.json)
fi

####################################################################################################################################################
#Running Preprocessing

if [[ $(jq -r .preprocess config.json) == 1 ]]; then
    mkdir "$out_data_dir/preprocess"
    if [ -d "$out_data_dir/croped_template" ]; then 
        echo "Preprocessing using croped templates from $out_data_dir/croped_template"
        singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess \
            -B "$out_data_dir/croped_template:/croped_template" /volatile/home/pl279327/rabies.sif \
            -p MultiProc --local_threads 22 preprocess /bids /preprocess --TR 1.5 \
            --labels /croped_template/croped_labels.nii.gz --commonspace_reg template_registration=Affine \
            --bold2anat_coreg registration=Affine --anat_template /croped_template/croped_template.nii \
            --brain_mask /croped_template/croped_mask.nii.gz --WM_mask /croped_template/croped_WMmask.nii.gz \
            --CSF_mask /croped_template/croped_CSFmask.nii.gz
    else
        echo "Preprocessing using default templates"
        singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess /volatile/home/pl279327/rabies.sif \
        -p MultiProc --local_threads 22 preprocess /bids /preprocess --TR 1.5 \
            --labels $(jq -r .crop_atlas.labels2copy_path config.json) --commonspace_reg template_registration=Affine \
            --bold2anat_coreg registration=Affine
    fi
fi

####################################################################################################################################################
#Running Confound Correction

if [[ $(jq -r .confound config.json) == 1 ]]; then
    #changed FD censoring from 0.05 to 0.02 ???
    # --match_number_timepoints True ???
    mkdir "$out_data_dir/confound"
    singularity run -B $out_data_dir/bids:/bids:ro -B $out_data_dir/preprocess:/preprocess -B $out_data_dir/confound:/confound \
        -B "$out_data_dir/croped_template:/croped_template" /volatile/home/pl279327/rabies.sif confound_correction /preprocess /confound \
        --highpass 0.01 --smoothing_filter 0.3 --lowpass 0.1 --conf_list CSF_signal mot_6 global_signal --edge_cutoff 30 \
        --frame_censoring FD_censoring=true,FD_threshold=0.05,DVARS_censoring=false,minimum_timepoint=3
fi

####################################################################################################################################################
#Running Codes for melodic

if [[ $(jq -r .melodic.RSS_common_bold config.json) == 1 ]]; then
    bash melodic_common_bold.sh $out_data_dir
fi

if [[ $(jq -r .melodic.global_melodic.do config.json) == 1 ]]; then

    cmd="bash melodic_pipeline.sh $out_data_dir"
    if [[ $(jq -r .melodic.global_melodic.specify_dimension config.json) == 1 ]]; then
        cmd+=" -d $(jq -r .melodic.global_melodic.dimension config.json)"
    fi

    if [[ $(jq -r .melodic.global_melodic.report config.json) == 1 ]]; then
        cmd+=" -r"
    fi

     if [[ $(jq -r .melodic.global_melodic.verbose config.json) == 1 ]]; then
        cmd+=" -v"
    fi

    echo -e "\n Running $cmd\n"
    eval "$cmd"
fi



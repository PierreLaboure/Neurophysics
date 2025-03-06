#!/bin/bash

#==============================================================================
#==============================================================================
# Created on 10/12/2024 by Pierre Labouré

#Process diffusion data preprocessed through dsi-studio to extract diffusion metrics from custom Atlas ROI
#==============================================================================
#==============================================================================

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rss


#make Atlas dirs for its brain extraction
atlas_average_path=$(jq -r .atlas_average_path config.json)
atlas_labels_path=$(jq -r .atlas_labels_path config.json)

atlas_parent_path=$(dirname "$atlas_average_path")
mkdir -p "$atlas_parent_path/input" "$atlas_parent_path/masks" "$atlas_parent_path/SSed"

RSS_input_atlas_path="$atlas_parent_path/input/atlas_0000.nii.gz"
RSS_masks_atlas_dir="$atlas_parent_path/masks"
RSS_masks_atlas_path="$RSS_masks_atlas_dir/atlas_mask.nii.gz"
RSS_SSed_atlas_path="$atlas_parent_path/SSed/SSed_atlas.nii.gz"


if [[ $(jq -r .RSS_atlas config.json) == 1 ]]; then
    #gzip and crop atlas to RSS input and RSS and rename output
    gzip -c $atlas_average and the abyss with the i_path > $RSS_input_atlas_path
    fslroi RSS_input_atlas_path RSS_input_atlas_path 0 -1 43 -1 0 -1
    RS2_predict -i "$atlas_parent_path/input" -o "$atlas_parent_path/masks" -m $(jq -r .pretrained_weights_path config.json) -device "cpu"
    mv "$RSS_masks_atlas_dir/atlas_0000.nii.gz" "$RSS_masks_atlas_dir/atlas_mask.nii.gz"

    #Get skull stripped Atlas Average
    fslmaths "$RSS_input_atlas_path" -mul "$RSS_masks_atlas_path" "$RSS_SSed_atlas_path"
fi


#Make dirs for database and RSS and transforms
mkdir -p $(jq -r .database_path config.json) $(jq -r .rss_path config.json) $(jq -r .ants_transforms_path config.json)

cohort_path=$(jq -r .cohort_path config.json)
cohort_name=$(basename "$cohort_path")
RSS_cohort_path="$(jq -r .rss_path config.json)/$cohort_name"
transforms_warp_cohort_path="$(jq -r .ants_transforms_path config.json)/Warp/$cohort_name"
transforms_registered_cohort_path="$(jq -r .ants_transforms_path config.json)/Registered/$cohort_name"

mkdir -p "$RSS_cohort_path" "$transforms_warp_cohort_path" "$transforms_registered_cohort_path"

RSS_input_path="$RSS_cohort_path/input"
RSS_masks_path="$RSS_cohort_path/masks"
RSS_SSed_path="$RSS_cohort_path/SSed"
mkdir -p "$RSS_input_path" "$RSS_masks_path" "$RSS_SSed_path"


#Identify subjects to process
if [[ $(jq -r .Process_Specific_Subjects.Process_Specific_Subjects config.json) == 1 ]]; then
    subjects_list=($(jq -r '.Process_Specific_Subjects.Subjects_List[]' config.json)) # use of paranthesis around the query outputs a bash array
else
    target_directory="$cohort_path/diff"
    subjects_list=($(find "$target_directory" -mindepth 1 -maxdepth 1 -type d -printf "%f\n"))
fi



#test_string="AS1061"
#if [[ " ${subjects_list[@]} " =~ " ${test_string} " ]]; then
#    echo "The string '${test_string}' is in the list."
#else
#    echo "The string '${test_string}' is NOT in the list."
#fi



#Copy RDI files for registration
if [[ $(jq -r .Copy_RDI_Anat.Copy_RDI config.json) == 1 ]]; then
    find "$cohort_path/diff" -type f -name '*rdi*' | while read file; do
        # Extract the subject name from the directory
        subdir=$(dirname "$file")
        subject_name=$(basename "$subdir")
        
        # Copy the file with the new naming formatfile
        if [[ " ${subjects_list[@]} " =~ " ${subject_name} " ]]; then
            cp "$file" "$RSS_input_path/${subject_name}_rdi_0000.nii.gz"
        fi
    done
fi

#Copy anat files for registration
if [[ $(jq -r .Copy_RDI_Anat.Copy_anat config.json) == 1 ]]; then
    # Process "anat" directory for files with "anat" in their names
    find "$cohort_path/anat" -type f -name '*anat*' | while read file; do
        # Extract the subject name from the directory
        subdir=$(dirname "$file")
        subject_name=$(basename "$subdir")

        # Define the output path for the copied file
        RSS_subject_anat_path="$RSS_input_path/${subject_name}_anat_0000.nii"
        
        # Copy the file and gzip it
        if [[ " ${subjects_list[@]} " =~ " ${subject_name} " ]]; then
            cp "$file" "$RSS_subject_anat_path"
            gzip "$RSS_subject_anat_path"
        fi
    done
fi


#Reorient anat images
if [[ $(jq -r .Reorient_anat.Reorient config.json) == 1 ]]; then
    reorient_script="$(pwd)/reorient_anat.sh"
    invert_dim=$(jq -r .Reorient_anat.Invert_dim config.json)

    for file in "$RSS_input_path"/*; do
        if [[ "$(basename "$file")" == *anat_0000* ]]; then
            filename="$(basename "$file")"
            subject_name=${filename%%_anat_0000*}
            if [[ " ${subjects_list[@]} " =~ " ${subject_name} " ]]; then
                # Build and run the command
                echo "reorientation of subject $subject_name anat scan"
                "$reorient_script" "$atlas_average_path" "$file" "$invert_dim"
            fi
        fi
    done
fi

#Skull strip images
if [[ $(jq -r .RSS_RDI_anat config.json) == 1 ]]; then
    RS2_predict -i "$RSS_input_path" -o "$RSS_masks_path" -m $(jq -r .pretrained_weights_path config.json) -device "cpu"
fi


#Register all RDI and anats
for file in "$RSS_input_path"/*; do
    filename=$(basename "$file")
    matching_mask_path="$RSS_cohort_path/masks/$filename"
    transform_prefix="$transforms_warp_cohort_path/${filename%%.*}"

    if [[ "$filename" == *anat_0000* ]]; then
        subject_name=${filename%%_anat_0000*}
        if [[ " ${subjects_list[@]} " =~ " ${subject_name} " ]]; then
            # Registration of Atlas onto anat
            if [[ $(jq -r .Register_atlas_2_anat.Register config.json) == 1 ]]; then
                echo "registering Atlas to Anat for $subject_name"
                n_process=$(jq -r .Register_atlas_2_anat.n_process config.json)

                fslmaths "$file" -mul "$matching_mask_path" "$RSS_SSed_path/$filename"

                if [[ $(jq -r .Register_atlas_2_anat.Quick config.json) == 1 ]]; then
                    antsRegistrationSyNQuick.sh -d 3 -f "$RSS_SSed_path/$filename" -m "$RSS_SSed_atlas_path" -o "$transform_prefix" -n "$n_process"
                else
                    antsRegistrationSyN.sh -d 3 -f "$RSS_SSed_path/$filename" -m "$RSS_SSed_atlas_path" -o "$transform_prefix" -n "$n_process"
                fi
            fi
            affine_transform_path="${transform_prefix}0GenericAffine.mat"
            warp_transform_path="${transform_prefix}1Warp.nii.gz"

            subject_name="${filename%%_anat_0000*}"
            registered_labels_path="$transforms_registered_cohort_path/${subject_name}_anat_labels.nii.gz"

            if [[ $(jq -r .Transform_atlas_2_anat.Transform config.json) == 1 ]]; then
                verbose=$(jq -r .Transform_atlas_2_anat.verbose config.json)
                #affine transform
                antsApplyTransforms -d 3 -i "$atlas_labels_path" -r "$file" -o "$registered_labels_path" -t "$affine_transform_path" -v "$verbose" -n NearestNeighbor
                #SyN transform
                antsApplyTransforms -d 3 -i "$registered_labels_path" -r "$file" -o "$registered_labels_path" -t "$warp_transform_path" -v "$verbose" -n NearestNeighbor
            fi
        fi
    fi
    
    if [[ "$filename" == *rdi_0000* ]]; then
        subject_name=${filename%%_rdi_0000*}
        if [[ " ${subjects_list[@]} " =~ " ${subject_name} " ]]; then
            # Registration of Atlas onto RDI
            if [[ $(jq -r .Register_atlas_2_RDI.Register config.json) == 1 ]]; then
                echo "registering Atlas to RDI for $subject_name"
                n_process=$(jq -r .Register_atlas_2_RDI.n_process config.json)

                fslmaths "$file" -mul "$matching_mask_path" "$RSS_SSed_path/$filename"

                if [[ $(jq -r .Register_atlas_2_RDI.Quick config.json) == 1 ]]; then
                    antsRegistrationSyNQuick.sh -d 3 -f "$RSS_SSed_path/$filename" -m "$RSS_SSed_atlas_path" -o "$transform_prefix" -n "$n_process"
                else
                    antsRegistrationSyN.sh -d 3 -f "$RSS_SSed_path/$filename" -m "$RSS_SSed_atlas_path" -o "$transform_prefix" -n "$n_process"
                fi
            fi
            affine_transform_path="${transform_prefix}0GenericAffine.mat"
            warp_transform_path="${transform_prefix}1Warp.nii.gz"

            #Registering Atlas Labels
            subject_name="${filename%%_rdi_0000*}"
            registered_labels_path="$transforms_registered_cohort_path/${subject_name}_diff_labels.nii.gz"
            if [[ $(jq -r .Transform_atlas_2_RDI.Transform config.json) == 1 ]]; then
                verbose=$(jq -r .Transform_atlas_2_RDI.verbose config.json)
                #affine transform
                antsApplyTransforms -d 3 -i "$atlas_labels_path" -r "$file" -o "$registered_labels_path" -t "$affine_transform_path" -v "$verbose" -n NearestNeighbor
                #SyN transform
                antsApplyTransforms -d 3 -i "$registered_labels_path" -r "$file" -o "$registered_labels_path" -t "$warp_transform_path" -v "$verbose" -n NearestNeighbor
            fi
        fi
    fi
done

#Extract metrics with a python script on directory for each subject
database_path=$(jq -r .database_path config.json)
database_cohort_path="$database_path/$cohort_name"
mkdir -p "$database_cohort_path"
db_prefix=$(jq -r .Extract_metrics.database_prefix config.json)
extract_verbose=$(jq -r .Extract_metrics.verbose config.json)
output_path="$database_cohort_path/$db_prefix.csv"

extract_script="$(pwd)/extract_metrics.py"

if [[ $(jq -r .Extract_metrics.Extract config.json) == 1 ]]; then
    python "$extract_script" -r "$transforms_registered_cohort_path" -o "$output_path" -c "$(pwd)/config.json" --verbose "$extract_verbose"
fi


#Merge all databases with specific prefix
merge_script="$(pwd)/merge_df.py"
if [[ $(jq -r .Merge_db.Merge config.json) == 1 ]]; then
    python "$merge_script" -c "$(pwd)/config.json"
fi




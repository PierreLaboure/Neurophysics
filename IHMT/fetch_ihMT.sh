#!/usr/bin/env bash

#==============================================================================
#==============================================================================
# Created on 18/02/2026 by Pierre Labouré

# Fetches ihMT data and puts them into a processing dir with the right naming
#==============================================================================
#==============================================================================

config_json="$1"

raw_data_dir=$(jq -r .raw_data_dir "$config_json")
subject_info_json=$(jq -r .subject_info "$config_json")
process_dir=$(jq -r .process_dir "$config_json")

command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed."; exit 1; }

for subj_dir in "$raw_data_dir"/*; do
    [ -d "$subj_dir" ] || continue
    subj_name=$(basename "$subj_dir")

    if ! jq -e --arg s "$subj_name" '.[$s]' "$subject_info_json" > /dev/null; then
        continue
    fi

    subj_type=$(jq -r --arg s "$subj_name" '.[$s].type' "$subject_info_json")

    echo "Processing subject: $subj_name (Type: $subj_type)"

    # --- Loop over modalities ---
    modalities=$(jq -r --arg s "$subj_name" '.[$s].modalities | keys[]' "$subject_info_json")

    for modality in $modalities; do
        # Get guiding subtypes
        guiding_subtypes=$(jq -r --arg s "$subj_name" --arg m "$modality" '.[$s].modalities[$m].guiding[]?' "$subject_info_json")

        # Loop over subtypes
        subtypes=$(jq -r --arg s "$subj_name" --arg m "$modality" '.[$s].modalities[$m].scans | keys[]' "$subject_info_json")

        for subtype in $subtypes; do

            # Detect subtype mode (array or object)
            subtype_definition=$(jq -c \
                --arg s "$subj_name" \
                --arg m "$modality" \
                --arg st "$subtype" \
                '.[$s].modalities[$m].scans[$st]' \
                "$subject_info_json")

            declare -a entries=()

            # ==========================================================
            # 🔹 MODE 1 — STANDARD (array of scan numbers)
            # ==========================================================
            if echo "$subtype_definition" | jq -e 'type=="array"' > /dev/null; then

                scans=$(echo "$subtype_definition" | jq -r '.[]')

                for scan_num in $scans; do
                    scan_dir="$subj_dir/$scan_num"
                    [ -d "$scan_dir" ] || continue

                    method_file="$scan_dir/method"
                    pdata_dir="$scan_dir/pdata"
                    [ -d "$pdata_dir" ] || continue

                    best_pdata=""
                    best_index=-1

                    for recon_dir in "$pdata_dir"/[0-9]*; do
                        [ -d "$recon_dir" ] || continue
                        recon_index=$(basename "$recon_dir")
                        nifti_file=$(find "$recon_dir" -type f -name "*.nii" | head -n 1)

                        if [ -n "$nifti_file" ] && (( recon_index > best_index )); then
                            best_index=$recon_index
                            best_pdata="$recon_dir"
                        fi
                    done

                    [ -n "$best_pdata" ] || continue
                    nifti_file=$(find "$best_pdata" -type f -name "*.nii" | head -n 1)

                    offset=$(awk '/^##\$PVM_EffSliceOffset=/{getline; print $1; exit}' "$method_file" 2>/dev/null)
                    offset=${offset:-0}

                    entries+=("$offset|$scan_num|$nifti_file")
                done

            # ==========================================================
            # 🔹 MODE 2 — EXPLICIT (scan → recon → file index)
            # ==========================================================
            elif echo "$subtype_definition" | jq -e 'type=="object"' > /dev/null; then

                # Loop over scan numbers
                for scan_num in $(echo "$subtype_definition" | jq -r 'keys[]'); do

                    recon_object=$(echo "$subtype_definition" | jq -c --arg sn "$scan_num" '.[$sn]')

                    for recon_num in $(echo "$recon_object" | jq -r 'keys[]'); do

                        file_index=$(echo "$recon_object" | jq -r --arg rn "$recon_num" '.[$rn]')

                        nifti_pattern="_${scan_num}_${recon_num}_${file_index}.nii"
                        nifti_file=$(find "$subj_dir/$scan_num/pdata/$recon_num" \
                                    -type f -name "*${nifti_pattern}" | head -n 1)

                        [ -f "$nifti_file" ] || continue

                        method_file="$subj_dir/$scan_num/method"
                        offset=$(awk '/^##\$PVM_EffSliceOffset=/{getline; print $1; exit}' "$method_file" 2>/dev/null)
                        offset=${offset:-0}

                        entries+=("$offset|$scan_num|$nifti_file")
                    done
                done
            fi

            # ==========================================================
            # 🔹 SORT + COPY (unchanged)
            # ==========================================================
            if [ ${#entries[@]} -gt 0 ]; then
                rank=1
                while IFS='|' read -r offset scan_num nifti_file; do
                    dest_dir="$process_dir/data/$subj_type/$modality/$subj_name"
                    mkdir -p "$dest_dir"
                    dest_file="${dest_dir}/${subj_name}_${subtype}_${rank}.nii"
                    cp "$nifti_file" "$dest_file"
                    echo "COPIED | $dest_file | Offset: $offset"
                    ((rank++))
                done < <(printf "%s\n" "${entries[@]}" | sort -t'|' -k1,1nr)
            fi

            unset entries
        done
    done
done
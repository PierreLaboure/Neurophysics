#!/usr/bin/env bash

#==============================================================================
#==============================================================================
# Created on 18/02/2026 by Pierre Labouré

# Reorients all images to standard orientation within the process directory
# Specific to bad conversions from PV360 to nifti format

#==============================================================================
#==============================================================================

config_json="$1"
process_data_dir="$(jq -r .process_dir "$config_json")/data"


find "$process_data_dir" -type f -name '*.nii*' | while read file; do
    echo "Setting $(basename "$file") to standard orientation"
    if [[ "$file" == *.nii ]]; then
        base_file="$file"
        file="${file}.gz"
        fslreorient2std "$base_file" "$file"
        rm -f "$base_file"
    else
        fslreorient2std "$file" "$file"
    fi

    # -------------------------------------------------
    # Step 1: Reorient and swap
    # -------------------------------------------------

    fslswapdim "$file" x z y "$file"

    # -------------------------------------------------
    # Step 2: Extract original qform matrix
    # -------------------------------------------------


    read r11 r12 r13 t1 <<< $(fslhd "$file" | grep "qto_xyz:1" | awk '{print $2, $3, $4, $5}')
    read r21 r22 r23 t2 <<< $(fslhd "$file" | grep "qto_xyz:2" | awk '{print $2, $3, $4, $5}')
    read r31 r32 r33 t3 <<< $(fslhd "$file" | grep "qto_xyz:3" | awk '{print $2, $3, $4, $5}')

    echo "Original translations:"
    echo "$t1 $t2 $t3"

    # -------------------------------------------------
    # Step 3: Delete orientation and reset qformcode
    # -------------------------------------------------

    fslorient -deleteorient "${file}"
    fslorient -setqformcode 1 "${file}"

    # -------------------------------------------------
    # Step 4: Apply correct permutation (swap Y/Z rows)
    # -------------------------------------------------

    # Because fslswapdim x z y swaps axes 2 and 3:
    # new_row2 = old_row3
    # new_row3 = old_row2

    new_r21=$r31
    new_r22=$r32
    new_r23=$r33
    new_t2=$t3

    new_r31=$r21
    new_r32=$r22
    new_r33=$r23
    new_t3=$t2

    # Row1 unchanged
    new_r11=$r11
    new_r12=$r12
    new_r13=$r13
    new_t1=$t1

    # -------------------------------------------------
    # Step 5: Write affine back
    # -------------------------------------------------

    fslorient -setqform \
    $new_r11 $new_r12 $new_r13 $new_t1 \
    $new_r21 $new_r22 $new_r23 $new_t2 \
    $new_r31 $new_r32 $new_r33 $new_t3 \
    0 0 0 1 \
    "${file}"

    # Also update sform to match (important)
    fslorient -setsform \
    $new_r11 $new_r12 $new_r13 $new_t1 \
    $new_r21 $new_r22 $new_r23 $new_t2 \
    $new_r31 $new_r32 $new_r33 $new_t3 \
    0 0 0 1 \
    "${file}"

    echo "Done. Affine preserved with correct axis permutation."
done




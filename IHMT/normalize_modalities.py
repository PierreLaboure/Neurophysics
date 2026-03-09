#!/usr/bin/env python3

import os
import json
import argparse
import numpy as np
import nibabel as nib
from sklearn.cluster import KMeans


# ==========================================================
# Utility Functions
# ==========================================================

def load_json(path):
    with open(path, "r") as f:
        return json.load(f)


def quantile_normalize_blocks(img, block_masks):
    """
    Symmetric multi-block quantile normalization.
    """

    block_values = [img[m].ravel() for m in block_masks]
    max_len = max(len(v) for v in block_values)

    sorted_blocks = []
    for v in block_values:
        v_sorted = np.sort(v)
        interp = np.interp(
            np.linspace(0, len(v_sorted) - 1, max_len),
            np.arange(len(v_sorted)),
            v_sorted
        )
        sorted_blocks.append(interp)

    reference = np.mean(sorted_blocks, axis=0)

    norm_img = img.copy()

    for mask, values in zip(block_masks, block_values):
        ranks = np.argsort(np.argsort(values))
        scaled = (ranks / (len(values) - 1) * (max_len - 1)).astype(int)
        norm_img[mask] = reference[scaled]

    return norm_img


def detect_blocks(img, brain_mask, n_blocks):
    """
    Detect blocks using k-means clustering on slice means.
    Assumes slicing along axis=1 (adjust if needed).
    """

    n_slices = img.shape[1]
    slice_means = []

    for s in range(n_slices):
        slice_data = img[:, s, :]
        slice_mask = brain_mask[:, s, :]
        if np.any(slice_mask):
            slice_means.append(slice_data[slice_mask].mean())
        else:
            slice_means.append(0)

    slice_means = np.array(slice_means).reshape(-1, 1)

    kmeans = KMeans(n_clusters=n_blocks, random_state=0)
    labels = kmeans.fit_predict(slice_means)

    block_masks = []

    for b in range(n_blocks):
        block_mask = np.zeros_like(img, dtype=bool)
        slice_indices = np.where(labels == b)[0]
        for s in slice_indices:
            block_mask[:, s, :] = True
        block_mask &= brain_mask
        block_masks.append(block_mask)

    return block_masks


# ==========================================================
# Main Normalization Logic
# ==========================================================

def normalize_subject(
    process_dir,
    subject_id,
    subject_info,
    norm_config,
    verbose=False
):

    subject_type = subject_info[subject_id]["type"]

    data_root = os.path.join(process_dir, "data", subject_type)
    transforms_root = os.path.join(process_dir, "transforms/Registered", subject_type)
    norm_root = os.path.join(process_dir, "normalized_data", subject_type)

    for modality, mod_cfg in norm_config["modalities"].items():

        metrics = mod_cfg.get("metrics", [])
        n_blocks = mod_cfg.get("n_blocks", 2)

        input_dir = os.path.join(data_root, modality, subject_id)
        if not os.path.isdir(input_dir):
            continue
        

        subject_atlas_dir = os.path.join(transforms_root, modality, subject_id)
        for file in os.listdir(subject_atlas_dir):
            if not file.endswith(".nii.gz"):
                continue
            subject_atlas_path = os.path.join(subject_atlas_dir, file)
            if verbose:
                print(f"[{subject_id}] Loading Labels map {file}")
            atlas_nii = nib.load(subject_atlas_path)
            atlas_data = atlas_nii.get_fdata()

        output_dir = os.path.join(norm_root, modality, subject_id)
        os.makedirs(output_dir, exist_ok=True)

        for file in os.listdir(input_dir):
            if not file.endswith(".nii.gz"):
                continue

            # Only normalize requested metrics
            if not any(metric in file for metric in metrics):
                continue

            img_path = os.path.join(input_dir, file)

            if verbose:
                print(f"[{subject_id}] Normalizing {modality} → {file}")

            img_nii = nib.load(img_path)
            img_data = img_nii.get_fdata()

            brain_mask = atlas_data != 0

            block_masks = detect_blocks(img_data, brain_mask, n_blocks)

            norm_data = quantile_normalize_blocks(img_data, block_masks)

            norm_data[~brain_mask] = 0

            out_file = file.replace(".nii.gz", "_norm.nii.gz")
            out_path = os.path.join(output_dir, out_file)

            nib.save(
                nib.Nifti1Image(norm_data, img_nii.affine, img_nii.header),
                out_path
            )


# ==========================================================
# CLI Entry Point
# ==========================================================

def main():

    parser = argparse.ArgumentParser()
    parser.add_argument("--process-dir", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--subject-info", required=True)
    parser.add_argument("--subjects", nargs="*", default=None)
    parser.add_argument("--verbose", action="store_true")

    args = parser.parse_args()

    config = load_json(args.config)
    subject_info = load_json(args.subject_info)

    norm_config = config.get("normalization", {})


    subjects = args.subjects if args.subjects else list(subject_info.keys())

    for subject_id in subjects:
        if subject_id not in subject_info:
            continue

        normalize_subject(
            args.process_dir,
            subject_id,
            subject_info,
            norm_config,
            verbose=args.verbose
        )


if __name__ == "__main__":
    main()

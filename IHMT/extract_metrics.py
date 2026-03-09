#!/usr/bin/env python3

import os
import json
import argparse
import numpy as np
import pandas as pd
import nibabel as nib


# ==========================================================
# Utilities
# ==========================================================

def load_json(path):
    with open(path, "r") as f:
        return json.load(f)


def build_roi_dict(roi_excel_path):
    roi_df = pd.read_excel(roi_excel_path)

    roi_dict = {}

    for roi_name in roi_df['hierarchy'].unique():
        sub_df = roi_df[roi_df['hierarchy'] == roi_name]

        right_labels = list(sub_df['right label'].dropna())
        left_labels = list(sub_df['left label'].dropna())

        if right_labels == left_labels:
            roi_dict[f"{roi_name}_middle"] = right_labels
        else:
            if right_labels:
                roi_dict[f"{roi_name}_right"] = right_labels
            if left_labels:
                roi_dict[f"{roi_name}_left"] = left_labels

    return roi_dict


def compute_intensity_stats(values):
    return {
        "mean": float(np.mean(values)),
        "std": float(np.std(values)),
        "min": float(np.min(values)),
        "max": float(np.max(values)),
        "median": float(np.median(values)),
    }


# ==========================================================
# Core Extraction
# ==========================================================

def extract_metrics(process_dir,
                    config,
                    subject_info,
                    subjects=None,
                    verbose=False):

    extract_cfg = config.get("extraction", {})


    roi_excel = config["ROI_index_list"]
    roi_dict = build_roi_dict(roi_excel)

    subjects_to_process = subjects if subjects else list(subject_info.keys())

    for modality, mod_cfg in extract_cfg["modalities"].items():

        mode = mod_cfg["mode"]
        metrics = mod_cfg.get("metrics", [])
        use_normalized = mod_cfg.get("use_normalized", False)

        if verbose:
            print(f"\n=== Processing modality: {modality} ===")

        results = []

        for subject_id in subjects_to_process:

            if subject_id not in subject_info:
                continue

            subject_meta = subject_info[subject_id]
            subject_type = subject_meta["type"]

            base_dir = "normalized_data" if use_normalized else "data"

            subject_dir = os.path.join(
                process_dir,
                base_dir,
                subject_type,
                modality,
                subject_id
            )

            # Loading subject modality specific atlas
            subject_atlas_dir = os.path.join(
                process_dir,
                "transforms/Registered",
                subject_type,
                modality,
                subject_id
            )
            for file in os.listdir(subject_atlas_dir):
                if not file.endswith(".nii.gz"):
                    continue
                subject_atlas_path = os.path.join(subject_atlas_dir, file)
                if verbose:
                    print(f"[{subject_id}] Loading Labels map {file}")
                atlas_nii = nib.load(subject_atlas_path)
                atlas_data = atlas_nii.get_fdata()
                flat_atlas = atlas_data.reshape(-1)

            if not os.path.isdir(subject_dir):
                continue

            for file in os.listdir(subject_dir):

                if not file.endswith(".nii.gz"):
                    continue

                # Filter metric names (only for intensity mode)
                if mode == "intensity":
                    if not any(metric in file for metric in metrics):
                        continue

                img_path = os.path.join(subject_dir, file)
                img_nii = nib.load(img_path)
                img_data = img_nii.get_fdata()
                flat_img = img_data.reshape(-1)

                if verbose:
                    print(f"[{subject_id}] {file}")

                # ---------------------------
                # TOTAL BRAIN
                # ---------------------------

                total_mask = flat_atlas != 0
                total_voxels = np.sum(total_mask)

                row_base = {
                    "subject": subject_id,
                    #**subject_meta,
                    "modality": modality,
                    "file": file,
                    "ROI_name": "total",
                    "ROI_label": 0,
                    "voxel_count": int(total_voxels),
                }

                if mode == "intensity":
                    stats = compute_intensity_stats(flat_img[total_mask])
                    row_base.update(stats)

                results.append(row_base)

                # ---------------------------
                # PER ROI
                # ---------------------------

                for roi_name, labels in roi_dict.items():

                    mask = np.isin(flat_atlas, labels)
                    voxel_count = np.sum(mask)

                    if voxel_count == 0:
                        continue

                    row = {
                        "subject": subject_id,
                        #**subject_meta,
                        "modality": modality,
                        "file": file,
                        "ROI_name": roi_name,
                        "ROI_label": labels[0],
                        "voxel_count": int(voxel_count),
                    }

                    if mode == "intensity":
                        stats = compute_intensity_stats(flat_img[mask])
                        row.update(stats)

                    results.append(row)

        if results:
            df = pd.DataFrame(results)

            output_dir = os.path.join(process_dir, "metrics_output")
            os.makedirs(output_dir, exist_ok=True)

            output_path = os.path.join(output_dir, f"{modality}_metrics.csv")
            df.to_csv(output_path, index=False)

            print(f"\nSaved → {output_path}")


# ==========================================================
# CLI
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

    extract_metrics(
        process_dir=args.process_dir,
        config=config,
        subject_info=subject_info,
        subjects=args.subjects,
        verbose=args.verbose
    )


if __name__ == "__main__":
    main()

import json
import nibabel as nib
import pandas as pd
import numpy as np
import os
import argparse


def extract_metrics():
    import json
    import nibabel as nib
    import pandas as pd
    import numpy as np
    import os
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('-r', type=str, required=True,
                        help='Registered cohort path: directory containing all atlas label maps registered to metric maps')
    parser.add_argument('-o', type=str, required=True,
                        help='Output CSV file (with .csv extension)')
    parser.add_argument('-c', type=str, required=True,
                        help='Path to JSON config file')
    parser.add_argument('--verbose', type=int, default=0,
                        help="Set to 1 for verbose mode")

    args = parser.parse_args()
    registered_cohort_path = args.r
    output_path = args.o
    config_path = args.c
    verbose = args.verbose

    # ---- Load configuration ----
    with open(config_path, "r") as outfile:
        config = json.load(outfile)

    metrics_list = config['diffusion_metrics_list']
    ROI_list = config['ROI_index_list']
    cohort_path = config['cohort_path']
    voxel_volume = config['voxel_volume']

    # ---- Build ROI dictionary ----
    ROI_df = pd.read_excel(ROI_list)
    ROI_labels_dict = {}
    for ROI_name in ROI_df['hierarchy']:
        ROI_labels_dict[ROI_name + '_right'] = list(ROI_df.loc[ROI_df['hierarchy'] == ROI_name, 'right label'])
        ROI_labels_dict[ROI_name + '_left'] = list(ROI_df.loc[ROI_df['hierarchy'] == ROI_name, 'left label'])

    results = []

    # ---- Process each subject ----
    for file in os.listdir(registered_cohort_path):
        filepath = os.path.join(registered_cohort_path, file)
        if not file.endswith(('diff_labels.nii.gz', 'anat_labels.nii.gz')):
            continue

        labels_map = nib.load(filepath).get_fdata().astype(np.int32)
        flat_labels = labels_map.ravel()

        # Precompute ROI indices (voxel indices)
        ROI_indices = {roi: np.nonzero(np.isin(flat_labels, labels))[0]
                       for roi, labels in ROI_labels_dict.items()}

        if 'diff_labels' in file:
            subject_name = file.split('_diff_labels')[0]
            subj_dir = os.path.join(cohort_path, 'diff', subject_name)
            if not os.path.isdir(subj_dir):
                continue

            if verbose:
                print(f"\n🧠 Processing diffusion metrics for {subject_name}")

            # Loop over diffusion metrics
            for metric_file in os.listdir(subj_dir):
                for metric_name in metrics_list:
                    if f"{metric_name}." not in metric_file:
                        continue

                    metric_path = os.path.join(subj_dir, metric_file)
                    metric_data = nib.load(metric_path).get_fdata().ravel()

                    # --- Whole-brain mask ---
                    idxs = np.nonzero(flat_labels != 0)[0]
                    vals = metric_data[idxs]
                    results.append({
                        'subject_name': subject_name,
                        'metric_name': metric_name,
                        'ROI_name': 'total',
                        'ROI_ID': [-1],
                        'metric_value': vals.mean(),
                        'metric_std': vals.std(),
                        'metric_min': vals.min(),
                        'metric_max': vals.max(),
                        'ROI_size': len(vals)
                    })

                    # --- Per-ROI stats ---
                    for roi, idxs in ROI_indices.items():
                        if len(idxs) == 0:
                            results.append({
                                'subject_name': subject_name,
                                'metric_name': metric_name,
                                'ROI_name': roi,
                                'ROI_ID': ROI_labels_dict[roi],
                                'metric_value': None,
                                'metric_std': None,
                                'metric_min': None,
                                'metric_max': None,
                                'ROI_size': 0
                            })
                            continue

                        vals = metric_data[idxs]
                        results.append({
                            'subject_name': subject_name,
                            'metric_name': metric_name,
                            'ROI_name': roi,
                            'ROI_ID': ROI_labels_dict[roi],
                            'metric_value': vals.mean(),
                            'metric_std': vals.std(),
                            'metric_min': vals.min(),
                            'metric_max': vals.max(),
                            'ROI_size': len(vals)
                        })

        elif 'anat_labels' in file:
            subject_name = file.split('_anat_labels')[0]

            if verbose:
                print(f"\n🧩 Processing anatomy for {subject_name}")

            # Total brain volume
            nonzero_vox = np.count_nonzero(flat_labels)
            total_volume = nonzero_vox * voxel_volume
            results.append({
                'subject_name': subject_name,
                'metric_name': 'volume',
                'ROI_name': 'total',
                'ROI_ID': [-1],
                'metric_value': total_volume,
                'metric_std': 0,
                'metric_min': 0,
                'metric_max': 0,
                'ROI_size': nonzero_vox
            })

            # Per-ROI volume
            for roi, idxs in ROI_indices.items():
                ROI_voxels = len(idxs)
                ROI_volume = ROI_voxels * voxel_volume
                results.append({
                    'subject_name': subject_name,
                    'metric_name': 'volume',
                    'ROI_name': roi,
                    'ROI_ID': ROI_labels_dict[roi],
                    'metric_value': ROI_volume,
                    'metric_std': 0,
                    'metric_min': 0,
                    'metric_max': 0,
                    'ROI_size': ROI_voxels
                })

    # ---- Build DataFrame once ----
    df = pd.DataFrame(results)
    df.to_csv(output_path, index=False)
    if verbose:
        print(f"\n✅ Metrics extracted successfully → {output_path}")



if __name__=="__main__":
    extract_metrics()
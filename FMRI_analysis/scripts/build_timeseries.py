import sys
import os

# Add project root to Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from neuro import TimeSeriesDataset
from neuro.utils import load_json

import numpy as np
import nibabel as nib
import json
import argparse
import os
import re
from collections import defaultdict




def build_subject_runs(base_dir):
    """
    Read confound corrected dir and extract all nifti files which correspond to a run
    Extract subject name and run name
    
    :param base_dir: Confound_correction dir path

    :Output: subject_runs | Type: dict(list) | key = subject_id | values = [(run_name, path to run.nii.gz file)]
    """
    pattern = re.compile(r"sub-([A-Za-z0-9]+)_.*?_run-(\d+)_bold")
    subjects_runs = defaultdict(list)

    for root, dirs, files in os.walk(base_dir):
        for f in files:
            if f.endswith(".nii.gz"):
                m = pattern.match(f)
                if m:
                    subj_id, run_num = m.groups()
                    full_path = os.path.join(root, f)
                    subjects_runs[subj_id].append((run_num, full_path))

    for subj_id in subjects_runs:
        subjects_runs[subj_id] = sorted(subjects_runs[subj_id], key=lambda x: int(x[0]))

    return subjects_runs


def build_timeseries(config):
    """
    Read path in config and save datasets of subjects in the given output dir
    
    :param config: Config file
    """
    confound_dir = config.get("confound_dir", "")

    #Load labels2roi given in config | Type dict | keys: "int" | values: "region name"
    #Converting keys from str to int
    labels2roi_path = config.get("labels2roi", "")
    labels2roi = load_json(labels2roi_path)
    labels2roi = {int(idx): name for idx, name in labels2roi.items()}
    Nroi = len(labels2roi.keys())

    #Declare roi_labels | Type list["roi names"] | Fed as input to dataset
    roi_labels = [roi for roi in labels2roi.values()]

    #Load atlas and make mask for each roi
    atlas_path = config.get("resampled_atlas_path", "")
    nib_atlas = nib.load(atlas_path)
    atlas = nib_atlas.get_fdata()
    roi_masks = np.array([atlas == label for label in labels2roi.keys()])

    #Load extra
    tr = config.get("tr", None)
    ds_out_dir = config.get("TimeSeries_output_dir", "")

    #Loop through subject_runs, read runs, average timeseries in voxels of same region
    subjects_runs = build_subject_runs(confound_dir)
    for subject, runs in subjects_runs.items():
        print(f"Loading subject {subject}")
        ds = TimeSeriesDataset(subject, atlas_path, roi_labels, tr = tr,)
        for run in runs:
            print(f"Loading run {run[0]}")
            nib_run_ts_map = nib.load(run[1])
            run_ts_map = nib_run_ts_map.get_fdata()
            T = run_ts_map.shape[-1]
            roi_ts = roi_masks.reshape(Nroi, -1) @ run_ts_map.reshape(-1, T)
            roi_ts /= roi_masks.reshape(Nroi, -1).sum(axis=1, keepdims=True)

            ds.add_run(run[0], roi_ts)
        ds.save(os.path.join(ds_out_dir, f"{subject}.h5"))




def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)

    args = parser.parse_args()
    config = load_json(args.config)

    build_timeseries(
        config
    )



if __name__ == "__main__":
    main()
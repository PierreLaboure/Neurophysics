import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import h5py
import numpy as np
from pathlib import Path
import json
import argparse
import re

from neuro.utils import load_json, get_subject_name, build_connectivity_path, build_aggregation_path
from neuro.connectivity import compute_connectivity_matrix
from neuro import TimeSeriesDataset
from neuro import ConnectivityDataset


def compute_connectivity(config):
    level = config.get("level", "")
    method = config.get("Connectivity_method", "")

    connectivity_in_dir = build_aggregation_path(config)
    output_dir = build_connectivity_path(config)
    os.makedirs(output_dir, exist_ok= True)

    aggregator_path = config.get("aggregator_path", "")

    for ds_path in os.listdir(connectivity_in_dir):
        if ds_path.endswith('.h5'):
            print(f"connectivity of aggregated subject {ds_path}")
            ds = TimeSeriesDataset.load(os.path.join(connectivity_in_dir, ds_path))

            subject = get_subject_name(ds_path)

            Cds = ConnectivityDataset(subject, method, ds.roi_labels, aggregator_path, level, history = ds.history)
            for run, ts in ds.runs.items():
                matrix = compute_connectivity_matrix(ts, method = Cds.method)
                Cds.add_run(run, matrix)
            Cds.save(os.path.join(output_dir, ds_path))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    config = load_json(args.config)

    compute_connectivity(
        config
    )


if __name__ == "__main__":
    main()
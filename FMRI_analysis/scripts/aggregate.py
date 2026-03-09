import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


import h5py
import numpy as np
from pathlib import Path
import json
import argparse

from neuro.utils import load_json, build_aggregation_path
from neuro import TimeSeriesDataset


def aggregate(config):
    in_dir = config.get("TimeSeries_output_dir", "")
    aggregator_path = config.get("aggregator_path", "")
    level = config.get("level", "")

    output_dir = build_aggregation_path(config)
    os.makedirs(output_dir, exist_ok= True)

    cache = {}

    for ds_path in os.listdir(in_dir):
        if ds_path.endswith('.h5'):
            print(f"processing subject {ds_path}")
            ds = TimeSeriesDataset.load(os.path.join(in_dir, ds_path))
            ds = ds.aggregate(aggregator_path, level, cache = cache)
            cache = ds.aggregate_cache[aggregator_path]
            ds.zscore()
            ds.save(os.path.join(output_dir, ds_path))



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    config = load_json(args.config)

    aggregate(
        config
    )


if __name__ == "__main__":
    main()
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import h5py
import numpy as np
from pathlib import Path
import json
import pandas as pd



def load_json(path):
    with open(path, "r") as f:
        return json.load(f)
    

def get_nested(d, key):
    if key in d:
        return d[key]
    for k, v in d.items():
        if isinstance(v, dict):
            result = get_nested(v, key)
            if result is not None:
                return result
    return None


def get_subject_name(filename):
    return os.path.splitext(filename)[0]


def build_aggregation_path(config):
    in_dir = config.get("TimeSeries_output_dir", "")
    level = config.get("level", "")
    agg_output_key = config.get("Aggregation_output_key", "")  

    path =  os.path.join(in_dir, agg_output_key, level)
    os.makedirs(path, exist_ok=True)
    return path

def build_connectivity_path(config):
    in_dir = config.get("TimeSeries_output_dir", "")
    agg_output_key = config.get("Aggregation_output_key", "")
    level = config.get("level", "")
    connectivity_output_key = config.get("Connectivity_output_key", "")
    method = config.get("Connectivity_method", "")

    path = os.path.join(in_dir, agg_output_key, level, connectivity_output_key, method)
    os.makedirs(path, exist_ok=True)
    return path


def build_analysis_path(config):
    in_dir = config.get("TimeSeries_output_dir", "")
    agg_output_key = config.get("Aggregation_output_key", "")
    level = config.get("level", "")
    connectivity_output_key = config.get("Connectivity_output_key", "")
    method = config.get("Connectivity_method", "")
    analysis_output_key = config.get("Analysis_output_key", "")

    analysis_factors = config.get("analysis_factor", "")
    filters = config.get("filters", "")

    joint_factors = "-".join(factor for factor in analysis_factors)
    joint_filters = "-".join(filter_name for filter_name in filters.values())

    analysis_output_key_2 = f"Factor-{joint_factors}_Filters-{joint_filters}"

    path = os.path.join(in_dir, agg_output_key, level, connectivity_output_key, method, analysis_output_key, analysis_output_key_2)
    os.makedirs(path, exist_ok=True)
    return path



def subject_info_to_df(path):

    with open(path) as f:
        info = json.load(f)

    rows = []

    for subj, data in info.items():
        row = {"subject": subj}

        for key, val in data.items():
            if not isinstance(val, dict):
                row[key] = val

        rows.append(row)
    return pd.DataFrame(rows)

def apply_filters(df, filters):
    for key, val in filters.items():
        df = df[df[key] == val]
    return df

def build_groups(df, factor, filters):

    groups = {}

    for value, subdf in df.groupby(factor):
        groups[f"{"-".join(factor for factor in value)}_{"-".join(filter_name for filter_name in filters.values())}"] = subdf["subject"].tolist()

    return groups


def make_groups(config):
    subject_info_path = config.get("subject_info", "")
    df = subject_info_to_df(subject_info_path)
    df_filtered = apply_filters(df, config["filters"]) 
    groups = build_groups(
        df_filtered,
        config["analysis_factor"],
        config["filters"]
    )
    return groups



def test_statistic(x, y, axis):
    return np.mean(x, axis=axis) - np.mean(y, axis=axis)
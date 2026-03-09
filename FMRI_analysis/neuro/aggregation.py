import h5py
import numpy as np
import nibabel as nib
from pathlib import Path
import json
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from collections import defaultdict

from neuro.utils import load_json, get_nested




class Aggregation:
    def __init__(self, name, matrix, labels):
        """
        
        :param name: Name
        :param matrix: numpy matrix | shape (N_out, N_in)
        :param labels: Type list(str) | list of names of output regions in order of apparition inside of matrices
        """
        self.name = name #Name of aggregation
        self.matrix = matrix#(N_out, N_in)
        self.labels = labels



def fetch_reference_roi_labels(agg_cfg):
    """
    Reads labels2roi in aggregator 
    
    :param agg_cfg: path to aggregator json file

    output : reference_labels2roi | Type dict | keys : reference ROI index, Type int | values : ROI name, Type str
    """
    reference_labels2roi_path = get_nested(agg_cfg, "reference_labels2roi_path")
    str_reference_labels2roi = load_json(reference_labels2roi_path)
    reference_labels2roi = {int(key): value for key, value in str_reference_labels2roi.items()}

    return reference_labels2roi



def load_base_name2index(agg_cfg):
    """
    Docstring for load_base_name2index
    
    :param agg_cfg: path to aggregator json file

    output : name2index | Type dict | keys : roi names | values : int in range(Nroi) (reference indices discarded)
    """
    reference_labels2roi = fetch_reference_roi_labels(agg_cfg)
    name2index = {n: i for i, n in enumerate(reference_labels2roi.values())}
    return name2index

def make_name2index(labels):
    """
    Convert labels to name2index
    
    :param labels: Type list("ROI names")

    output : name2index | Type dict | keys : roi names | values : int in range(Nroi)
    """
    return {n: i for i, n in enumerate(labels)}



def identity_aggregation(agg_cfg):
    """
    Identity aggregation:
    fine atlas → fine atlas
    """
    
    reference_labels2roi = fetch_reference_roi_labels(agg_cfg)
    N_ROI = len(reference_labels2roi)
    
    A = np.eye(N_ROI, dtype=float)

    return Aggregation(
        name="identity",
        matrix=A,
        labels=list(reference_labels2roi.values())
    )



def build_matrix(groups, roi_index):
    """
    Create aggregation matrix
    
    :param groups: Type dict | keys : "Coarser Region cluster name" | values : list [ "Finer Region Cluster names ]
    :param roi_index: Equivalent to "name2index" | Type dict | keys : roi names | values : int in range(Nroi)

    output : A : Aggregation matrix | Type numpy.ndarray | shape (N_out, N_in)
    output : labels | Type list(str) | list of names of output regions in order of apparition inside of matrices
    """
    n_out = len(groups)
    n_in = len(roi_index)

    A = np.zeros((n_out, n_in))
    labels = []
    for i, (name, rois) in enumerate(groups.items()):
        idx = [roi_index[r] for r in rois]
        A[i, idx] = 1 / len(idx)
        labels.append(name)
    return A, labels



def resolve_aggregation(name, agg_cfg, cache = {}):
    """
    Read aggregator json file recursively to create Aggregation object at given level of aggregation
    
    :param name: Level of aggregation fetch in aggregator json file
    :param aggregator json file path
    :param cache: Cahe to use in case aggregation has already been resolved
    """
    
    if name in cache:
        return cache[name]

    cfg = agg_cfg[name]

    if "type" in cfg and cfg["type"] == "identity":
        #If identity aggregation, aggregating but with identity
        return identity_aggregation(agg_cfg)

    if "source" in cfg:
        # If aggregation level has parent, resolve it before
        parent = resolve_aggregation(
            cfg["source"], agg_cfg
        )
        
        A_local, labels = build_matrix(
            cfg["regions"],
            make_name2index(parent.labels)
        )

        A_total = A_local @ parent.matrix

    else:
        #build matrix using specified aggregation level
        A_total, labels = build_matrix(
            cfg["regions"],
            load_base_name2index(agg_cfg)
        )

    agg = Aggregation(name, A_total, labels)
    return agg
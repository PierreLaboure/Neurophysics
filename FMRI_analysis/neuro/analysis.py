import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from collections import defaultdict
import argparse

import h5py
import numpy as np
import pandas as pd
import nibabel as nib
from pathlib import Path
import json
import matplotlib.pyplot as plt
from statsmodels.stats.multitest import fdrcorrection
from scipy.stats import f_oneway

from neuro import ConnectivityDataset, TimeSeriesDataset
from neuro.utils import load_json, get_subject_name, build_connectivity_path, build_analysis_path, build_aggregation_path, make_groups, test_statistic



def get_aggregation_roi_names(config):
    path = build_aggregation_path(config)
    for file in os.listdir(path):
        if file.endswith(".h5"):
            ds = TimeSeriesDataset.load(os.path.join(path, file))
            return ds.roi_labels


# -----------------------------
# 1️⃣ Load group connectivity
# -----------------------------
def assemble_group_connectivity(connectivity_dir, subjects_list=None):
    """
    Load all ConnectivityDataset .h5 files in a directory.
    Returns:
        group_matrices: dict of subject_id -> (Nroi x Nroi) numpy arrays
    """
    group_matrices = {}
    for f in os.listdir(connectivity_dir):
        if f.endswith(".h5"):
            subj_id = get_subject_name(f)
            if subjects_list is not None:
                for config_subject in subjects_list:
                    if config_subject in f:
                        filepath = os.path.join(connectivity_dir, f)
                        cds = ConnectivityDataset.load(filepath)
                        group_matrices[subj_id] = cds.average_runs()
                        print(f"Match found between {config_subject} and {f}")
                        continue
                #print(f"Match not found for {f}")
    return group_matrices

# -----------------------------
# 2️⃣ Group statistics
# -----------------------------
def compute_group_mean(matrices):
    """Compute mean connectivity across subjects."""
    return np.mean(list(matrices.values()), axis=0)

def compute_group_variance(matrices):
    """Compute variance across subjects."""
    return np.var(list(matrices.values()), axis=0)

# -----------------------------
# 3️⃣ Edgewise statistical tests
# -----------------------------
def edgewise_ttest(group1, group2, test_method = "ttest"):
    """Compute t-test per edge (ROI-ROI) between two groups.
    group1, group2: dicts subject_id -> matrix
    Returns: t_matrix, p_matrix
    """
    from scipy.stats import ttest_ind, mannwhitneyu, permutation_test

    all1 = np.stack(list(group1.values()))
    all2 = np.stack(list(group2.values()))
    t_matrix = np.zeros(all1.shape[1:])
    p_matrix = np.zeros(all1.shape[1:])

    for i in range(all1.shape[1]):
        for j in range(all1.shape[2]):
            x = all1[:, i, j]
            y = all2[:, i, j]
            # Skip if all NaNs
            if np.all(np.isnan(x)) and np.all(np.isnan(y)):
                t_matrix[i, j] = np.nan
                p_matrix[i, j] = np.nan
                continue
            if test_method == 'ttest':
                t_matrix[i, j], p_matrix[i, j] = ttest_ind(x, y, nan_policy="omit")
            elif test_method == "U":
                t_matrix[i, j], p_matrix[i, j] = mannwhitneyu(x, y, alternative='two-sided')
            elif test_method == "Permutation":
                result = permutation_test((x, y), test_statistic, vectorized=True, n_resamples=1000, alternative='two-sided')
                t_matrix[i, j], p_matrix[i, j] = result.statistic, result.pvalue
            else:
                raise ValueError(f"Unknown test method {test_method}. Options are ttest, U, Permutation") 


    return t_matrix, p_matrix


def edgewise_anova(group_matrices):
    """
    Perform one-way ANOVA across multiple groups for each edge in connectivity matrices.

    Parameters
    ----------
    group_matrices : dict
        Dictionary mapping group_name -> list of (Nroi x Nroi) matrices (subjects)

    Returns
    -------
    F_matrix : np.ndarray
        (Nroi x Nroi) array of F-statistics
    p_matrix : np.ndarray
        (Nroi x Nroi) array of p-values
    """
    # Collect all subjects
    all_groups = list(group_matrices.keys())
    sample_matrix = next(iter(next(iter(group_matrices.values())).values()))
    Nroi = sample_matrix.shape[0]

    F_matrix = np.zeros((Nroi, Nroi))
    p_matrix = np.zeros((Nroi, Nroi))

    # Iterate over upper triangle only (symmetric matrix)
    for i in range(Nroi):
        for j in range(i, Nroi):
            # Gather values for this edge across all groups
            samples = []
            for g in all_groups:
                edge_vals = [m[i, j] for m in group_matrices[g].values()]
                samples.append(edge_vals)
            # Perform ANOVA
            F, p = f_oneway(*samples)
            F_matrix[i, j] = F
            F_matrix[j, i] = F  # symmetric
            p_matrix[i, j] = p
            p_matrix[j, i] = p  # symmetric

    return F_matrix, p_matrix


def fdr_correction(p_matrix, alpha=0.05):
    """Apply FDR correction across all edges."""
    p_flat = p_matrix.flatten()
    mask = ~np.isnan(p_flat)
    corrected = np.full_like(p_flat, False, dtype=bool)
    if np.any(mask):
        rejected, _ = fdrcorrection(p_flat[mask], alpha=alpha)
        '''plt.figure()
        plt.plot(np.sort(p_flat))
        plt.show()'''
        corrected[mask] = rejected
    return corrected.reshape(p_matrix.shape)

# -----------------------------
# 4️⃣ Graph metrics (optional)
# -----------------------------
def compute_graph_metrics(matrix, labels, threshold=None, title = None):
    """Compute simple graph metrics."""
    import networkx as nx

    if threshold is not None:
        mat = matrix.copy()
        mat[np.abs(mat) < threshold] = 0
    else:
        mat = matrix.copy()

    G = nx.from_numpy_array(mat, nodelist = labels)
    metrics = {
        "strength": dict(G.degree(weight="weight")),
        "clustering": nx.clustering(G, weight="weight"),
        "efficiency": nx.global_efficiency(G)
    }
    print(metrics)
    nx.draw_circular(G, with_labels=True)
    plt.title(title, fontsize = 20)
    plt.show()
    return metrics

# -----------------------------
# 5️⃣ Plotting
# -----------------------------
def plot_heatmap(matrix, roi_names=None, save_path=None, vmin=-1, vmax=1, cmap='seismic', title = None):
    fig, ax = plt.subplots(figsize=(12, 12))
    im = ax.imshow(matrix, cmap=cmap, vmin=vmin, vmax=vmax)
    if roi_names is not None:
        ticks = np.arange(len(roi_names))
        ax.set_xticks(ticks)
        ax.set_yticks(ticks)
        ax.set_xticklabels(roi_names, rotation=90)
        ax.set_yticklabels(roi_names)
    plt.colorbar(im, ax=ax)
    plt.title(title)
    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    plt.show()

def plot_difference(matrix1, matrix2, roi_names=None, save_path=None, cmap='bwr'):
    diff = matrix1 - matrix2
    plot_heatmap(diff, roi_names=roi_names, save_path=save_path, vmin=-np.max(np.abs(diff)), vmax=np.max(np.abs(diff)), cmap=cmap)

# -----------------------------
# 6 Result Tables
# -----------------------------

def save_significant_edges_table(
    p_matrix,
    group_means,
    g1,
    g2,
    roi_names,
    output_csv,
    alpha=0.05
):

    mean_g1 = group_means[g1]
    mean_g2 = group_means[g2]

    rows = []
    N = p_matrix.shape[0]

    for i in range(N):
        for j in range(i + 1, N):  # upper triangle only

            p = p_matrix[i, j]

            if np.isnan(p):
                continue

            if p < alpha:

                if p < 0.01:
                    sig = "<0.01"
                else:
                    sig = "<0.05"

                rows.append({
                    "Connection": f"{roi_names[i]}-{roi_names[j]}",
                    "p_value": p,
                    "significance": sig,
                    f"Connectivity_{g1}": mean_g1[i, j],
                    f"Connectivity_{g2}": mean_g2[i, j]
                })

    df = pd.DataFrame(rows)

    df = df.sort_values("p_value")

    df.to_csv(output_csv, index=False)





# -----------------------------
# 6️⃣ Main
# -----------------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    config = load_json(args.config)

    aggregation_roi_names = get_aggregation_roi_names(config)
    connectivity_dir = build_connectivity_path(config)
    groups = make_groups(config)

    output_dir = build_analysis_path(config)
    os.makedirs(output_dir, exist_ok=True)

    # Load connectivity matrices
    group_matrices = {}
    for group_name, subjects in groups.items():
        group_matrices[group_name] = assemble_group_connectivity(
            connectivity_dir,
            subjects
        )

    for group_names, group in group_matrices.items():
        print(group_names, list(group.keys()))

    # Compute group stats
    group_means = {}
    for group_name, matrices in group_matrices.items():
        group_means[group_name] = compute_group_mean(matrices)
        
        #metrics = compute_graph_metrics(group_means[group_name], aggregation_roi_names, threshold = 0.05, title = group_name)
    
    # Edgewise stats
    group_names = list(group_matrices.keys())
    if len(group_names) == 2:
        g1, g2 = group_names
        
        t_matrix, p_matrix = edgewise_ttest(
            group_matrices[g1],
            group_matrices[g2],
            test_method = config.get("test_method")
        )
        
        sig_mask = fdr_correction(p_matrix, alpha=0.05)

        save_significant_edges_table(
            p_matrix,
            group_means,
            g1,
            g2,
            roi_names=aggregation_roi_names,
            output_csv=os.path.join(output_dir, f"{g1}_vs_{g2}_significant_edges.csv")
        )
    
    else:
        F_matrix, p_matrix = edgewise_anova(group_matrices)
        print(p_matrix.shape)
        #sig_mask = fdr_correction(p_matrix, alpha=0.05)

    # Save results
    for group_name, mean_matrix in group_means.items():
        np.save(
            os.path.join(output_dir, f"{group_name}_mean.npy"),
            mean_matrix
        )
        plot_heatmap(
            mean_matrix,
            save_path=os.path.join(output_dir, f"{group_name}_mean.png"),
            roi_names=aggregation_roi_names,
            title = group_name
        )

    if len(group_names) == 2:
        np.save(os.path.join(output_dir, f"{g1}_vs_{g2}_t_matrix.npy"), t_matrix)
        np.save(os.path.join(output_dir, f"{g1}_vs_{g2}_p_matrix.npy"), p_matrix)
        np.save(os.path.join(output_dir, f"{g1}_vs_{g2}_sig_mask.npy"), sig_mask)
        plot_difference(list(group_means.values())[0], list(group_means.values())[1], save_path=os.path.join(output_dir, f"{g1}_vs_{g2}_difference_mean.png"), roi_names=aggregation_roi_names)
        plot_heatmap(sig_mask, save_path=os.path.join(output_dir, f"{g1}_vs_{g2}_sig_mask.png"), roi_names=aggregation_roi_names)
        p_matrix[p_matrix>=0.05] = 1
        plot_heatmap(p_matrix, save_path=os.path.join(output_dir, f"{g1}_vs_{g2}_p_matrix.png"), roi_names=aggregation_roi_names)
        '''p_matrix[p_matrix>=0.05] = 1
        plot_heatmap(p_matrix, roi_names=aggregation_roi_names)'''



if __name__ == "__main__":
    main()
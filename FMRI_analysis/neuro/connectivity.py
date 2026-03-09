import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


import numpy as np
from sklearn.covariance import GraphicalLassoCV
import matplotlib.pyplot as plt
import h5py



class ConnectivityDataset:
    def __init__(self, subject, method, roi_names, aggregator, level, history = None):
        self.subject = subject
        self.method = method
        self.roi_names = roi_names
        self.aggregator = aggregator
        self.level = level
        self.matrices = {}  # run_id -> (Nroi x Nroi) matrix
        self.history = history if history is not None else []  # track which method, aggregation, preprocessing applied

    #####################################
    #History related methods

    #Method to add anything to history
    def add_history(self, step, **params):
            import datetime

            record = {
                "step": step,
                "timestamp": datetime.datetime.now().isoformat(),
                **params
            }

            self.history.append(record)

    #Method to save history to a specific path
    def write_history_log(self, log_path):
        import json
        with open(log_path, "w") as f:
            json.dump(self.history, f, indent = 3)

    #Method to return the last step performed on the dataset
    def last_step(self):
        return self.history[-1]["step"]
    
    #Method to print all steps in history, light description
    def describe(self):
        for h in self.history:
            print(h["step"], h["timestamp"])

    #Method to print all steps in history, full description
    def describe_full(self):
        print(self.history)
    #####################################


    #####################################
    #runs processing methods

    def add_run(self, run_id, matrix):
        self.matrices[run_id] = matrix
        self.history.append(f"Added {run_id} connectivity with {self.method}")
        self.add_history("add_run", run_id = run_id, method = self.method)

    def get_matrix(self, run_id):
        return self.matrices[run_id]
    
    def average_runs(self):
        self.add_history("average_runs")
        return np.nanmean(list(self.matrices.values()), axis = 0)
    
    def flatten(self, run_id, average=False):
        self.add_history("flatten", run_id = run_id, average=average)
        if average : 
            matrix = self.average_runs()
        else:
            matrix = self.matrices[run_id]
        return flatten_upper_triangle(matrix)
    #####################################
    
    
    #####################################
    def plot(self, run_id, save_path = None, vmin = -1, vmax = 1, cmap = 'seismic'):
        matrix = self.matrices[run_id]
    
        fig, ax = plt.subplots(figsize = (15, 15))
        im = ax.imshow(matrix, cmap = cmap, vmin = vmin, vmax = vmax)
        ticks = np.arange(0, len(self.roi_names))
        tick_labels = self.roi_names
        ax.set_xticks(ticks)
        ax.set_yticks(ticks)
        ax.set_xticklabels(tick_labels, rotation = 90)
        ax.set_yticklabels(tick_labels)
        fig.colorbar(im, ax=ax)
        plt.tight_layout()
        if save_path:
            plt.savefig(save_path)
        plt.show()


    def save(self, filepath):
        import json

        with h5py.File(filepath, "w") as f:

            f.attrs["subject"] = self.subject
            f.attrs["method"] = self.method
            f.attrs["roi_names"] = self.roi_names
            f.attrs["aggregator"] = self.aggregator
            f.attrs["level"] = self.level


            matrices_grp = f.create_group("matrices")
            for run_id, matrix in self.matrices.items():
                matrices_grp.create_dataset(
                    run_id,
                    data=matrix,
                    compression="gzip"
                )

            hist_grp = f.create_group("history")
            for k, step in enumerate(self.history):
                hist_grp.create_dataset(
                    f"{k:04d}",
                    data = json.dumps(step)
                )


    @classmethod
    def load(cls, filepath):
        import json

        with h5py.File(filepath, "r") as f:

            obj = cls(
                subject=f.attrs["subject"],
                method = f.attrs["method"],
                roi_names=f.attrs["roi_names"],
                aggregator = f.attrs["aggregator"],
                level = f.attrs["level"],
            )

            for run in f["matrices"]:
                obj.matrices[run] = f["matrices"][run][:]

            hist_grp = f["history"]
            for key in sorted(hist_grp.keys()):
                step_json = hist_grp[key][()].decode("utf-8")
                obj.history.append(json.loads(step_json))
        return obj
    


def compute_connectivity_matrix(timeseries, method = 'pearson'):
    if method == 'Pearson':
        corr = np.corrcoef(timeseries)
        corr[np.diag_indices(corr.shape[0], ndim=2)] = 0
        return np.arctanh(corr)
    elif method == 'ICOV':
        X = timeseries.T
        X -= X.mean(axis=0, keepdims=True)
        X /= X.std(axis=0, keepdims=True)

        # --- 1) find valid ROI columns: at least one non-nan ---
        valid = ~np.all(np.isnan(X), axis=0)   # shape: (R,)
        Xv = X[:, valid]                       # (T × Rvalid)

        # --- 2) drop nans inside kept ROI columns (they should be gone by std) ---
        Xv = np.nan_to_num(Xv, copy=False)

        # --- 3) fit only on valid ROIs ---
        est = GraphicalLassoCV()
        est.fit(Xv)

        # --- 4) build partial correlation on valid subset ---
        prec_v = est.precision_
        d = np.sqrt(np.diag(prec_v))
        pc_v = -prec_v / np.outer(d, d)
        np.fill_diagonal(pc_v, 1.0)

        # --- 5) re-embed into full (R × R) matrix ---
        R = X.shape[1]
        ICOV = np.zeros((R, R)) * np.nan    # or zeros((R,R)) if you prefer 0-fill

        ICOV[np.ix_(valid, valid)] = pc_v
        return ICOV
    elif method == 'cov':
        return np.cov(timeseries)
    
    else:
        raise ValueError(f"Unknown method {method}")


def flatten_upper_triangle(matrix):
    assert (len(matrix.shape)==2 and matrix.shape[0]==matrix.shape[1]) , "Input Matrix should be 2 dimensional"
    N = matrix.shape[0]
    return matrix(np.triu_indices(N, k = 0))
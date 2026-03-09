import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import h5py
import numpy as np
from pathlib import Path
import json
import matplotlib.pyplot as plt

from collections import defaultdict

from neuro.aggregation import resolve_aggregation
from neuro.utils import load_json

class TimeSeriesDataset:
    
    def __init__(self,
                 subject, #Type str | name of the subject
                 atlas, #Type str | path to atlas used for this dataset
                 roi_labels, #Type list(str) | list of names of regions in order of apparition inside of matrices
                 tr=None, #Type int | TR metadata
                 history = None #Type list(dict) | list of history entries see add_history
                 ):

        self.subject = subject
        self.atlas = atlas
        self.roi_labels = roi_labels
        self.tr = tr
        self.history = history if history is not None else []

        self.runs = {}        #Type dict(run_name: timeseries) 
        self.metadata = {}    #Unused
        self.aggregate_cache = defaultdict(dict) # Type defaultdict(dict) | {"aggregator_path" : {"level" : aggregation_object}}


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

    #Add run to Dataset
    def add_run(self, run_name, timeseries):
        """
        run_name : str
        timeseries: (Nroi × T)
        """
        self.runs[run_name] = np.asarray(timeseries)
        self.add_history("add_run", run_name = run_name)

    #Display all timeseries of all ROIs within run
    def plot_run(self, run_name):
        """
        run_name : str
        """
        plt.figure()
        plt.plot(self.runs[run_name].T, label = self.roi_labels)
        plt.legend()
        plt.show()

    #Time concatenate runs in dataset
    def concatenate_runs(self):
        self.add_history("concatenate_runs")
        return np.concatenate(
            [self.runs[r] for r in sorted(self.runs)],
            axis=1
        )
    
    #Apply aggregation to runs in dataset
    def aggregate(self, aggregator_path, level, cache = None):
        """
        :param aggregator_path: Path to Aggregator.json containing hierarchical aggregation scheme
        :param level: Hierarchy at which aggregation is used within Aggregator_path
        :param cache: Cached aggregation params to prevent recomputing
        """

        #Reading aggregator at given level to create aggregation object. Using cache if already computed
        agg_cfg = load_json(aggregator_path)
        aggregation = resolve_aggregation(level, agg_cfg, cache)

        #Creating new aggregated dataset and dumping aggregation into its cache
        self.add_history("aggregate", aggregator_path = aggregator_path, name = level, out_shape = aggregation.matrix.shape[0])
        agg_ds = TimeSeriesDataset(
            subject=self.subject,
            atlas=self.atlas,
            roi_labels=aggregation.labels,
            tr=self.tr,
            history = self.history
        )
        agg_ds.aggregate_cache[aggregator_path][level] = aggregation

        #Aggregating runs | setting nan values to 0 to prevent all nan output
        for run, ts in self.runs.items():
            ts[np.isnan(ts)] = 0
            agg_ds.runs[run] = aggregation.matrix @ ts

        return agg_ds
    
    #Standardizing timeseries
    def zscore(self):
        self.add_history("z-score")
        for r in self.runs:
            ts = self.runs[r]
            self.runs[r] = (
                ts - ts.mean(axis=1, keepdims=True)
            ) / ts.std(axis=1, keepdims=True)

    #
    def connectivity(self, method="pearson"):
        conn = {}
        for run, ts in self.runs.items():
            conn[run] = np.corrcoef(ts)
        return conn
    #####################################
    

    #####################################
    #IO methods

    #Save dataset
    def save(self, filepath):
        import json

        with h5py.File(filepath, "w") as f:

            f.attrs["subject"] = self.subject
            f.attrs["atlas"] = self.atlas
            f.attrs["TR"] = self.tr

            f.attrs["roi_labels"] = self.roi_labels

            '''roi_grp = f.create_group("roi_labels")
            for k, v in self.roi_labels.items():
                roi_grp.attrs[k] = v'''

            runs_grp = f.create_group("runs")
            for run, ts in self.runs.items():
                runs_grp.create_dataset(
                    run,
                    data=ts,
                    compression="gzip"
                )

            print(self.history)
            hist_grp = f.create_group("history")
            for k, step in enumerate(self.history):
                hist_grp.create_dataset(
                    f"{k:04d}",
                    data = json.dumps(step)
                )

    #Load dataset
    @classmethod
    def load(cls, filepath):
        import json

        with h5py.File(filepath, "r") as f:

            obj = cls(
                subject=f.attrs["subject"],
                atlas=f.attrs["atlas"],
                roi_labels=f.attrs["roi_labels"],
                tr=f.attrs["TR"],
            )

            for run in f["runs"]:
                obj.runs[run] = f["runs"][run][:]

            hist_grp = f["history"]
            for key in sorted(hist_grp.keys()):
                step_json = hist_grp[key][()].decode("utf-8")
                obj.history.append(json.loads(step_json))
        return obj





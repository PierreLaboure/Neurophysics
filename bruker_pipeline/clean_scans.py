import numpy as np
import pandas as pd
import argparse
import os
import re
import sys

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Optional app description')
    parser.add_argument('helper_path', type=str,
                        help='path to helper.csv')
    parser.add_argument('scans_path', type=str,
                        help='path to Scans.xlsx')
    

    args = parser.parse_args()
    helper_path = args.helper_path
    scans_path = args.scans_path

    df = pd.read_excel(scans_path, header = 0, names = ['sub', 'scan', 'processing'])
    df.loc[df['processing'].isna(), "processing"] = "P1"
    df1 = pd.read_csv(helper_path)

    df['is_first'] = df['sub'].notna() & (df['sub'].shift(1).isna() | (df.index == df.index[0]))
    sub_idx = df[df['is_first']].index.union([df.index[-1]+1])

    dict_scans_processings = {}


    for subject_id in df1["RawData"].unique():
        dict_scans_processings[subject_id] = {0:0}


    for i in range(len(sub_idx)-1):
        filled = False
        for k in range(sub_idx[i]+1, sub_idx[i+1]):

            v = df.loc[k, ["scan", 'processing']]

            if not pd.isna(v["scan"]):
                dict_scans_processings[df.loc[sub_idx[i], "sub"]][int(v["scan"].strip('E'))] = int(v["processing"].strip('P'))
                filled = True
        if filled:
            del dict_scans_processings[df.loc[sub_idx[i], "sub"]][0]

    filter1 = [df1.loc[i, 'ScanID'] in (dict_scans_processings[df1.loc[i, "RawData"]].keys()) for i in df1.index]
    df1 = df1[filter1]
    filter2 = [df1.loc[i, 'RecoID'] == dict_scans_processings[df1.loc[i, 'RawData']][df1.loc[i, 'ScanID']] for i in df1.index]
    df1 = df1[filter2]
    
    df1.to_csv(helper_path, index = False)

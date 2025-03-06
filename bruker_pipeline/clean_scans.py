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
    parser.add_argument('-d', '--denoise', type=int,
                        help='1 if we want to use scans denoised by bruker instead of base scans, 0 otherwise')
    

    args = parser.parse_args()
    helper_path = args.helper_path
    scans_path = args.scans_path
    denoise = args.denoise

    df = pd.read_excel(scans_path, header = 0, names = ['sub', 'scan'])

    df1 = pd.read_csv(helper_path)

    df['is_first'] = df['sub'].notna() & (df['sub'].shift(1).isna() | (df.index == df.index[0]))
    sub_idx = df[df['is_first']].index.union([df.index[-1]+1])

    dict = {}
    for subject_id in df1["RawData"].unique():
        dict[subject_id] = [0]

    for i in range(len(sub_idx)-1):
        scans = []
        for k in range(sub_idx[i]+1, sub_idx[i+1]):
            v = df.loc[k, "scan"]
            if not pd.isna(v):
                scans.append(int(v.strip('E')))
        dict[df.loc[sub_idx[i], "sub"]] = scans


    filter = [df1.loc[i, 'ScanID'] in (dict[df1.loc[i, "RawData"]]) for i in df1.index]
    df1 = df1[filter]

    if denoise:
        df1_filtered = df1.loc[df1.groupby(['ScanID', 'RawData'])['RecoID'].idxmax()]
        df1_filtered = df1_filtered.reset_index(drop=True)
    else:
        df1_filtered = df1.loc[df1.groupby(['ScanID', 'RawData'])['RecoID'].idxmin()]
        df1_filtered = df1_filtered.reset_index(drop=True)
    
    df1_filtered.to_csv(helper_path, index = False)

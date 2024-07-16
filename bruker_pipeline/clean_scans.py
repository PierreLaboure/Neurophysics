import numpy as np
import pandas as pd
import argparse
import os
import re


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Optional app description')

    parser.add_argument('helper_path', type=str,
                        help='path to helper.csv')
    parser.add_argument('scans_path', type=str,
                        help='path to Scans.xlsx')
    

    args = parser.parse_args()
    helper_path = args.helper_path
    scans_path = args.scans_path

    df = pd.read_excel(scans_path, header = 0, names = ['sub', 'scan'])
    AN = df.loc[:, "sub"].str.contains("AN").fillna(False)
    sub_idx = df[AN].index.union([df.index[-1]+1])

    dict = {}

    for i in range(len(sub_idx)-1):
        scans = []
        for k in range(sub_idx[i]+1, sub_idx[i+1]):
            v = df.loc[k, "scan"]
            if not pd.isna(v):
                scans.append(int(v.strip('E')))
        dict[re.sub(r'\D', '', df.loc[sub_idx[i], "sub"])] = scans

    df1 = pd.read_csv(helper_path)
    df1["sub"] = df1["RawData"].str.extract(r'(\d+)', expand=False)
    filter = [df1.loc[i, 'ScanID'] in (dict[df1.loc[i, "sub"]]) for i in df1.index]

    df1[filter].drop(columns=["sub"]).to_csv(helper_path, index = False)

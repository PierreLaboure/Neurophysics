import numpy as np
import pandas as pd
import argparse
import os


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

    dict = {}
    for i, sub in enumerate(AN):
        if sub:
            scans = []
            scans.append(int(df.loc[i+1, 'scan'].strip('E')))
            scans.append(int(df.loc[i+2, 'scan'].strip('E')))
            scans.append(int(df.loc[i+3, 'scan'].strip('E')))

            sub = df.loc[i, 'sub'][-4:]

            dict[sub] = scans

    df1 = pd.read_csv(helper_path)
    df1["sub"] = df1["RawData"].str[2:6]
    filter = [df1.loc[i, 'ScanID'] in (dict[df1.loc[i, "sub"]]) for i in df1.index]

    df1[filter].drop(columns=["sub"]).to_csv(helper_path, index = False)

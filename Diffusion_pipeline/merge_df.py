def merge_df():
    import json
    import pandas as pd
    import os
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('-c', type=str, required=True,
                        help='absolute path to json config file')

    
    args = parser.parse_args()
    config_path = args.c

    with open(config_path, "r") as outfile:
        config = json.load(outfile)

    database_path = config["database_path"]
    database_prefix = config["Merge_db"]["database_prefix"]
    merged_prefix = config["Merge_db"]["Merged_prefix"]
    merged_db_path = os.path.join(database_path, merged_prefix + '.csv')

    db_list = []

    for path, dirs, files in os.walk(database_path):
        for file in files:
            if database_prefix in file:
                cohort_name = path.split('/')[-1]
                df = pd.read_csv(os.path.join(path, file))
                df['cohort'] = cohort_name
                db_list.append(df)

    stacked_df = pd.concat(db_list, ignore_index=True)

    stacked_df.to_csv(merged_db_path)


if __name__=="__main__":
    merge_df()
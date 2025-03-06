import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd

import os 
import glob
import pickle
import argparse

from aggregate_utils import FC_df_tri


def main(args=None):
	parser = argparse.ArgumentParser(description='Process some parameters.')

	parser.add_argument('--output_path_1', type=str, required=True,
						help='Path to output directory of group 1')
	parser.add_argument('--output_path_2', type=str, required=True,
						help='Path to output directory of group 2')

	parser.add_argument('--group_name_1', type=str, required=True,
						help='name of group 1')
	parser.add_argument('--group_name_2', type=str, required=True,
						help='name of group 2')


	# Parsing arguments
	args = parser.parse_args(args)
	output_path_1 = args.output_path_1
	output_path_2 = args.output_path_2
	group_name_1 = args.group_name_1
	group_name_2 = args.group_name_2

	FC_matrix_files_1 = glob.glob(os.path.join(output_path_1, "FC_matrix_data", "*"))
	parameters_file = os.path.join(output_path_1, "parameters.pkl")

	with open(parameters_file, "rb") as fp:   #Pickling
			parameters_1 = pickle.load(fp)

	FC_matrix_files_2 = glob.glob(os.path.join(output_path_2, "FC_matrix_data", "*"))
	parameters_file = os.path.join(output_path_2, "parameters.pkl")

	with open(parameters_file, "rb") as fp:   #Pickling
			parameters_2 = pickle.load(fp)

	if parameters_1['ROI_names'] != parameters_2['ROI_names']:
			raise Exception('error, not the same ROIs')

	short_names = []
	for label in parameters_1['ROI_names']:
		short_names.append(''.join([word[0] for word in label.split(' ')]))

	df_1 = FC_df_tri(FC_matrix_files_1, short_names, group_name_1)
	df_2 = FC_df_tri(FC_matrix_files_2, short_names, group_name_2)
	df = pd.concat([df_1, df_2])

	sns.boxplot(df, x = 'Connection', y = 'Correlation', hue = "Group")
	plt.show()

if __name__ == "__main__":
	main()
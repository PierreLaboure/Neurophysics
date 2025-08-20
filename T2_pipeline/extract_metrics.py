import json
import nibabel as nib
import pandas as pd
import numpy as np
import os
import argparse


def extract_metrics():
    import json
    import nibabel as nib
    import pandas as pd
    import numpy as np
    import os
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--verbose', type=int, help="Set this if you like being talked to. You will have "
                                                               "to be a good listener/reader.")
    args = parser.parse_args()
    verbose = args.verbose


    config_path = "./config.json"
    with open(config_path, "r") as outfile:
        config = json.load(outfile)

    process_data_dir = config['process_data_dir']
    ROI_list = config['ROI_index_list']



    ROI_map_path = os.path.join(process_data_dir, "preprocess/bold_datasink/commonspace_labels")
    for dirpath, dirnames, filenames in os.walk(ROI_map_path):
        if filenames:
            ROI_map_path = os.path.join(dirpath, filenames[0])
            break
    ROI_map_path = os.path.join(process_data_dir, 'croped_template/croped_labels.nii.gz')
    commonspace_labels_nii = nib.load(ROI_map_path)
    commonspace_labels = commonspace_labels_nii.get_fdata()




    T2map_dir = os.path.join(process_data_dir, "commonspace_T2map")


    subject_type_path = config['subject_type']
    with open(subject_type_path, "r") as outfile:
        subject_type_dict = json.load(outfile)

    ## Creating ROI Labels Dictionnary
    ROI_df = pd.read_excel(ROI_list)
    ROI_labels_dict = {}
    for ROI_name in ROI_df['hierarchy']:
        ROI_labels_right = list(ROI_df[ROI_df['hierarchy']==ROI_name]['right label'])
        ROI_labels_left = list(ROI_df[ROI_df['hierarchy']==ROI_name]['left label'])
        ROI_labels_dict[ROI_name + '_right'] = ROI_labels_right
        ROI_labels_dict[ROI_name + '_left'] = ROI_labels_left



    ## Extraction of Diffusion and Anat Metrics

    #Initialization of Database dictionnary
    dict_df = {'subject_name':[],
            'treatment':[],
            'type':[],
            'ROI_name':[],
            'ROI_number':[],
            'T2_mean':[],
            'T2_std':[],
            'T2_min':[],
            'T2_max':[],
            'ROI_size':[],
            }

    #Loop through registered atlas label maps
    for file in os.listdir(T2map_dir):
        if file.endswith('_anat.nii.gz'):
            print(f'processing {file}')
            filepath = os.path.join(T2map_dir, file)
            T2map_nii = nib.load(filepath)
            T2map = T2map_nii.get_fdata().reshape(-1)

            subject_name = file.split('_commonspace')[0]
            before_after_tag = file.split('_')[1]
            number_tag = file.split('_')[0]

            mask = (commonspace_labels!=0)
            flat_mask = np.where(mask.reshape(-1))

            dict_df['subject_name'].append(subject_name)
            dict_df['treatment'].append(before_after_tag)
            dict_df['type'].append(subject_type_dict[number_tag])
            dict_df['ROI_name'].append('total')
            dict_df['ROI_number'].append(0)
            dict_df['T2_mean'].append(T2map[flat_mask[0]].mean())
            dict_df['T2_std'].append(T2map[flat_mask[0]].std())
            dict_df['T2_min'].append(T2map[flat_mask[0]].min())
            dict_df['T2_max'].append(T2map[flat_mask[0]].max())
            dict_df['ROI_size'].append(len(flat_mask[0]))

            for ROI_name in ROI_labels_dict:
                ROI_labels = ROI_labels_dict[ROI_name]
                mask = np.isin(commonspace_labels, ROI_labels)
                flat_mask = np.where(mask.reshape(-1))
                if len(flat_mask[0])!=0:
                    dict_df['subject_name'].append(subject_name)
                    dict_df['treatment'].append(before_after_tag)
                    dict_df['type'].append(subject_type_dict[number_tag])
                    dict_df['ROI_name'].append(ROI_name)
                    dict_df['ROI_number'].append(ROI_labels[0])
                    dict_df['T2_mean'].append(T2map[flat_mask[0]].mean())
                    dict_df['T2_std'].append(T2map[flat_mask[0]].std())
                    dict_df['T2_min'].append(T2map[flat_mask[0]].min())
                    dict_df['T2_max'].append(T2map[flat_mask[0]].max())
                    dict_df['ROI_size'].append(len(flat_mask[0]))


    

    database = pd.DataFrame(dict_df)
    output_path = os.path.join(process_data_dir, "commonspace_T2map/database.csv")
    database.to_csv(output_path, index=False)



if __name__=="__main__":
    extract_metrics()
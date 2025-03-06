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
    parser.add_argument('-r', type=str, required=True,
                        help='Registered Cohort Path : absolute path to a director containing all atlas label maps registered to metric maps')
    parser.add_argument('-o', type=str, required=True,
                        help='absolute path to save a csv file. Contains .csv extension')
    parser.add_argument('-c', type=str, required=True,
                        help='absolute path to json config file')
    parser.add_argument('--verbose', type=int, help="Set this if you like being talked to. You will have "
                                                               "to be a good listener/reader.")
    
    args = parser.parse_args()

    registered_cohort_path = args.r
    output_path = args.o
    config_path = args.c
    verbose = args.verbose

    with open(config_path, "r") as outfile:
        config = json.load(outfile)

    metrics_list = config['diffusion_metrics_list']
    print(metrics_list)
    ROI_list = config['ROI_index_list']
    cohort_path = config['cohort_path']
    voxel_volume = config['voxel_volume']


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
            'metric_name':[],
            'ROI_name':[],
            'metric_value':[],
            'metric_std':[],
            'metric_min':[],
            'metric_max':[],
            'ROI_size':[],
            }

    #Loop through registered atlas label maps
    for file in os.listdir(registered_cohort_path):
        filepath = os.path.join(registered_cohort_path, file)
        labels_nib_map = nib.load(filepath)
        labels_map = labels_nib_map.get_fdata()

        #Process diffusion label maps
        if file.endswith('diff_labels.nii.gz'):
            subject_name = file.split('_diff_labels')[0]
            cohort_subject_dir_path = os.path.join(cohort_path, 'diff', subject_name)
            #Loop through diffusion metrics
            for metric_nii_map in os.listdir(cohort_subject_dir_path):
                for metric_name in metrics_list:
                    if (metric_name+'.') in metric_nii_map:
                        if verbose==1:
                            print(f'processing {subject_name} for metric {metric_name}')
                        #Load diffusion metric map
                        metric_nib_map = nib.load(os.path.join(cohort_subject_dir_path, metric_nii_map))
                        metric_map = metric_nib_map.get_fdata().reshape(-1)

                        mask = (labels_map!=0)
                        flat_mask = np.where(mask.reshape(-1))
                        metric_value = metric_map[flat_mask[0]].mean()
                        metric_std = metric_map[flat_mask[0]].std()
                        metric_min = metric_map[flat_mask[0]].min()
                        metric_max = metric_map[flat_mask[0]].max()
                        ROI_size = len(flat_mask[0])

                        dict_df['subject_name'].append(subject_name)
                        dict_df['metric_name'].append(metric_name)
                        dict_df['ROI_name'].append('total')
                        dict_df['metric_value'].append(metric_value)
                        dict_df['metric_std'].append(metric_std)
                        dict_df['metric_min'].append(metric_min)
                        dict_df['metric_max'].append(metric_max)
                        dict_df['ROI_size'].append(ROI_size)

                        # Extract metric for all ROIs
                        for ROI_name in ROI_labels_dict:
                            ROI_labels = ROI_labels_dict[ROI_name]
                            mask = np.isin(labels_map, ROI_labels)
                            flat_mask = np.where(mask.reshape(-1))
                            metric_value = metric_map[flat_mask[0]].mean()
                            metric_std = metric_map[flat_mask[0]].std()
                            metric_min = metric_map[flat_mask[0]].min()
                            metric_max = metric_map[flat_mask[0]].max()
                            ROI_size = len(flat_mask[0])
 
                            dict_df['subject_name'].append(subject_name)
                            dict_df['metric_name'].append(metric_name)
                            dict_df['ROI_name'].append(ROI_name)
                            dict_df['metric_value'].append(metric_value)
                            dict_df['metric_std'].append(metric_std)
                            dict_df['metric_min'].append(metric_min)
                            dict_df['metric_max'].append(metric_max)
                            dict_df['ROI_size'].append(ROI_size)


        #Process Anat maps
        if file.endswith('anat_labels.nii.gz'):
            subject_name = file.split('_anat_labels')[0]
            cohort_subject_dir_path = os.path.join(cohort_path, 'anat', subject_name)
            if verbose==1:
                print(f'processing {subject_name} for volume')
    
            #Compute total volume of whole brain in mm3
            total_volume = len(np.where(labels_map)[0])*voxel_volume
            total_voxel = len(np.where(labels_map)[0])
            dict_df['subject_name'].append(subject_name)
            dict_df['metric_name'].append('volume')
            dict_df['ROI_name'].append('total')
            dict_df['metric_value'].append(total_volume)
            dict_df['metric_std'].append(0)
            dict_df['metric_min'].append(0)
            dict_df['metric_max'].append(0)
            dict_df['ROI_size'].append(total_voxel)

            #Compute volume of all ROI in mm3
            for ROI_name in ROI_labels_dict:
                ROI_labels = ROI_labels_dict[ROI_name]
                mask = np.isin(labels_map, ROI_labels)
                anat_metric = len(np.where(mask.reshape(-1))[0])*voxel_volume
                ROI_size = len(np.where(mask.reshape(-1))[0])

                dict_df['subject_name'].append(subject_name)
                dict_df['metric_name'].append('volume')
                dict_df['ROI_name'].append(ROI_name)
                dict_df['metric_value'].append(anat_metric)
                dict_df['metric_std'].append(0)
                dict_df['metric_min'].append(0)
                dict_df['metric_max'].append(0)
                dict_df['ROI_size'].append(ROI_size)

    database = pd.DataFrame(dict_df)
    database.to_csv(output_path)



if __name__=="__main__":
    extract_metrics()
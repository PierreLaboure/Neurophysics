                antsRegistration \
                --dimensionality 3 \
                --float 0 \
                --output ["$transform_prefix","${transform_prefix}Warped.nii.gz","${transform_prefix}InverseWarped.nii.gz"] \
                --interpolation Linear \
                --use-histogram-matching 1 \
                --initial-moving-transform ["$core_guiding","$core_template",1] \
                \
                --transform Rigid[0.05] \
                --metric MI["$core_guiding","$core_template",1,64,Regular,0.3] \
                --convergence [2000x1000x500x250,1e-7,15] \
                --shrink-factors 6x4x2x1 \
                --smoothing-sigmas 3x2x1x0vox \
                \
                --transform Affine[0.05] \
                --metric MI["$core_guiding","$core_template",1,64,Regular,0.3] \
                --convergence [2000x1000x500x250,1e-7,15] \
                --shrink-factors 6x4x2x1 \
                --smoothing-sigmas 3x2x1x0vox \
                \
                --transform SyN[0.08,3,0] \
                --metric CC["$core_guiding","$core_template",1,4] \
                --convergence [200x100x70x50,1e-6,10] \
                --shrink-factors 6x4x2x1 \
                --smoothing-sigmas 3x2x1x0vox \
                --verbose 1
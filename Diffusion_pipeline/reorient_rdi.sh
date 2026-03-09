#!/bin/bash

# Source and target images
# Source is the atlas
# Target is the anat
source_image="$1"
target_image="$2"
invert_dim="$3"

#Optionnel, spécifique à mon cas
if [[ $invert_dim == 1 ]]; then
    fslswapdim $target_image -x -y -z $target_image
fi

echo "Orientation updated for $target_image to match $source_image."

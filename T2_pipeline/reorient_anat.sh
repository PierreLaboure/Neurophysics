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

# Get the sform and qform from the source image
sform=$(fslorient -getsform $source_image)
qform=$(fslorient -getqform $source_image)

# Apply the sform and qform to the target image
fslorient -setsform $sform $target_image
fslorient -setqform $qform $target_image

echo "Orientation updated for $target_image to match $source_image."

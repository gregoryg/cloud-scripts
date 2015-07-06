#!/bin/bash
fromregion=us-east-1
ami="ami-954ba3fe"
aminame="DMX-h Windows (version 8.1.2)"
amidesc="DMX-h development and server environment 8.1.2"
rpath=/tmp/all-region-names.txt

aws ec2 describe-regions|grep RegionName|cut -d":" -f2|tr -d '[ "]' > $rpath

read -p "Copying ami $ami from $fromregion to all current regions.  Proceed? (y/n) " yn
if [ "y" != $yn ]; then
    echo "Exiting."
    exit
fi

for i in `cat $rpath`
do
    if [ "$fromregion" == "$i" ]; then
	echo "Skipping region $i (same as source region)"
    else
	echo $i
	aws ec2 copy-image --no-dry-run \
	    --source-region "$fromregion" \
	    --region "$i" \
	    --source-image-id "$ami" \
	    --name "$aminame" \
	    --description "$amidesc"
    fi
done 2>&1 |  tee copy-ami-to-all-regions.log





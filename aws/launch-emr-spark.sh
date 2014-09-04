#!/bin/bash

./elastic-mapreduce --create --alive \
    --credentials credentials-ggrubbs-IAM.json \
    --name "ironspark" \
    --bootstrap-action s3://syncsortpocsoftware/bootstrap-emr-dmxh.sh \
    --bootstrap-name "Ironcluster/DMX-h" \
    --bootstrap-action s3://syncsortpocsoftware/bootstrap-emr-spark.rb \
    --bootstrap-name "Spark/Shark" \
    --instance-type m3.xlarge \
    --instance-count 4 \
    --ami-version 3.0.3

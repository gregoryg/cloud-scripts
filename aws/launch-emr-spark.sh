#!/bin/bash
LOGSDIR=s3://syncsortpoclogs/ironbluster

./elastic-mapreduce --create --alive \
    --credentials credentials-ggrubbs-IAM.json \
    --name "ironspanker" \
    --bootstrap-action s3://syncsortpocsoftware/bootstrap/bootstrap-emr-dmxh.sh \
    --bootstrap-name "Ironcluster/DMX-h" \
    --bootstrap-action s3://syncsortpocsoftware/bootstrap/bootstrap-emr-spark-1-1.rb \
    --bootstrap-name "Spark/Shark" \
    --instance-type m3.xlarge \
    --instance-count 4 \
    --ami-version 3.0.3
#     # --ami-version 3.2.1

# aws emr create-cluster \
#     --name "ironspanker" \
#     --no-auto-terminate \
#     --no-visible-to-all-users \
#     --log-uri $LOGSDIR \
#     --enable-debugging \
#     --ami-version 3.1.0 \
#     --instance-groups InstanceGroupType=MASTER,InstanceType=m3.xlarge,InstanceCount=1 \
#     InstanceGroupType=CORE,InstanceType=m3.xlarge,InstanceCount=3 \
#     --bootstrap-actions Name="Aggregate logs", Path=s3://elasticmapreduce/bootstrap-actions/configure-hadoop, \
#     Args=["-y","yarn.log-aggregation-enable=true","-y","yarn.log-aggregation.retain-seconds=-1","-y","yarn.log-aggregation.retain-check-interval-seconds=3000","-y","yarn.nodemanager.remote-app-log-dir=s3://mybucket/logs"] \
#     Name="Ironcluster/DMX-h", Path=s3://syncsortpocsoftware/bootstrap/bootstrap-emr-dmxh \
#     Name="Spark/Shark", Path=s3://syncsortpocsoftware/bootstrap/bootstrap-emr-spark-1-1.rb
    

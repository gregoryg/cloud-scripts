aws emr create-cluster \
    --name "Spark cluster" \
    --no-visible-to-all-users \
    --ami-version 4.0.0 \
    --instance-type m3.xlarge \
    --instance-count 4 \
    --ec2-attributes KeyName=ironcluster-se \
    --applications Name=Spark, Hive \
    --bootstrap-actions Name="DMX-h",Path=s3://syncsortpocsoftware/bootstrap/bootstrap-emr-dmxh.sh \
    --use-default-roles


# aws emr create-cluster \
#     --name ironspanker \
#     --no-visible-to-all-users \
#     --ami-version 3.6 \
#     --instance-type m3.xlarge \
#     --instance-count 4 \
#     --ec2-attributes KeyName=ironcluster-se \
#     --applications Name=Hive \
#     --bootstrap-actions Name="Spark",Path=s3://support.elasticmapreduce/spark/install-spark \
    Name="DMX-h",Path=s3://syncsortpocsoftware/bootstrap/bootstrap-emr-dmxh.sh


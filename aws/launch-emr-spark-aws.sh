aws emr create-cluster \
    --no-visible-to-all-users \
    --name ironspanker \
    --ami-version 3.6 \
    --instance-type m3.xlarge \
    --instance-count 4 \
    --ec2-attributes KeyName=ironcluster-se \
    --applications Name=Hive \
    --bootstrap-actions Name="Spark",Path=s3://support.elasticmapreduce/spark/install-spark \
    Name="DMX-h",Path=s3://syncsortpocsoftware/bootstrap/bootstrap-emr-dmxh.sh


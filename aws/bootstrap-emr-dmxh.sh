#!/usr/bin/env bash

## dump the environment active at bootstrap script time
env > ~hadoop/bootstrap-env.txt

## is this the master node?
EMR_CONFIG_PATH='/mnt/var/lib/info/instance.json'
ismaster=`python -c 'import json; fp=open("'$EMR_CONFIG_PATH'","r"); print json.load(fp)["isMaster"]'`

# change directory to hadoop user home for duration of script
cd ~hadoop

# Get Hadoop version in order to build setup-hdfs.sh script
hversion=`hadoop version | head -1 | cut -d' ' -f2` 

# Install tools
sudo yum -y install mlocate htop tmux git

# copy DMX-h files from dmx S3 bucket
dmxrpm="dmexpress-7.14.3-1.x86_64.rpm"
echo Installing DMX-h
hadoop fs -copyToLocal s3://syncsortpocsoftware/dmexpress/"$dmxrpm"

## install the pre-licensed DMX-h .rpm and set paths globally
sudo rpm -i "$dmxrpm" && echo "Installed $dmxrpm"
echo '
DMXHOME=/usr/dmexpress
PATH=$PATH:$DMXHOME/bin:/home/hadoop/.versions/hive-0.11.0/bin
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DMXHOME/lib
DMX_HADOOP_MRV=2
DMX_HADOOP_STREAMING_JAR=/home/hadoop/contrib/streaming/hadoop-streaming.jar
HDFS_SOURCE_DIR=/UCA/HDFSData/Source
HDFS_TARGET_DIR=/UCA/HDFSData/Target
DMXHADOOP_EXAMPLES_DIR=/UCA
LOCAL_SOURCE_DIR=/UCA/Data/Source
export PATH LD_LIBRARY_PATH DMXHOME DMX_HADOOP_MRV DMX_HADOOP_STREAMING_JAR HDFS_SOURCE_DIR HDFS_TARGET_DIR DMXHADOOP_EXAMPLES_DIR LOCAL_SOURCE_DIR
' | sudo tee /etc/profile.d/dmexpress.sh

## Things to be done only on the master node
if [ "True" == "$ismaster" ]; then
    echo 'export PS1="[\u@MASTER \W]$ "' >> ~hadoop/.bashrc
## install, configure, and start the DMX daemon
    echo Configuring dmxd on master node
    . /etc/profile
    cd $DMXHOME
    sudo killall dmxd
    sudo ./install <<EOF
2
n
y
y

EOF

echo "
#!/bin/bash
## update slaves file on master node; DOES NOT WORK because runs too early
hdfs dfsadmin -report | grep ^Name | cut -f2 -d: | tr -d ' ' > /home/hadoop/.versions/$hversion/etc/hadoop/slaves

hadoop fs -mkdir -p /UCA/HDFSData
" > ~hadoop/setup-hdfs.sh
chmod u+rx ~hadoop/setup-hdfs.sh

fi


## personal environment setup
    hadoop fs -copyToLocal  s3://syncsortpocsoftware/.tmux.conf

# ## just to make s3 a little easier to deal with
#     echo Installing s3cmd
#     wget -O -  http://s3tools.org/repo/RHEL_6/s3tools.repo | sudo tee /etc/yum.repos.d/s3tools.repo
#     sudo yum -y install s3cmd
# fi

# ## copy over UCA jobs and data and set up script to set up env
echo "
	sudo mkdir /UCA
	sudo chown hadoop /UCA
	cd /UCA
	echo Copy UCA tar files
	hadoop fs -copyToLocal s3://syncsortpocsoftware/DMX-h_UCA_Solutions.tar.gz
	hadoop fs -copyToLocal s3://syncsortpocsoftware/DMX-h_UCA_Data.tar.gz
	echo Un-tar Data and solutions
	tar xvf DMX-h_UCA_Solutions.tar.gz
	tar xvf DMX-h_UCA_Data.tar.gz
	echo set up data for examples
	./bin/prep_dmx_example.sh ALL
" > ~hadoop/setup-uca.sh
chmod u+rx ~hadoop/setup-uca.sh

    sudo updatedb&

    echo Done with bootstrap script

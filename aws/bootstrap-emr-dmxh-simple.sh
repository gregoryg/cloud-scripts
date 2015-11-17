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
sudo yum -y install mlocate htop git curl wget finger aws-cli

## Use the following lines if installing from .rpm
# copy DMX-h files from dmx S3 bucket
dmxrpmdir="8.4"
dmxrpm="dmexpress-8.4-1.x86_64.rpm"
echo Installing DMX-h
hadoop fs -copyToLocal s3://<SOFTWARE_BUCKET>/dmexpress/"$dmxrpmdir"/"$dmxrpm"

## install the pre-licensed DMX-h .rpm and set paths globally
sudo rpm -i "$dmxrpm" && echo "Installed $dmxrpm"
echo '
DMXHOME=/usr/dmexpress
PATH=$PATH:$DMXHOME/bin
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DMXHOME/lib
DMX_HADOOP_MRV=2
export PATH LD_LIBRARY_PATH DMXHOME DMX_HADOOP_MRV
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

fi
    
sudo updatedb&

echo Done with bootstrap script

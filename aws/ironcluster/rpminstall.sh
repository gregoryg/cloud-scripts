#!/bin/bash
## is this the master node?
EMR_CONFIG_PATH='/mnt/var/lib/info/instance.json'
ismaster=`python -c 'import json; fp=open("'$EMR_CONFIG_PATH'","r"); print json.load(fp)["isMaster"]'`
bucket=sserpxemd
path=8.2.3/dmexpress-ironcluster-8.2.3-licensed.tar.gz
wget --no-check-certificate -S -T 10 -t 5 http://$bucket.s3.amazonaws.com/$path
tar zxf dmexpress-ironcluster-8.2.3-licensed.tar.gz
sudo rm -rf /usr/dmexpress
sudo mv dmexpress /usr/

## Things to be done only on the master node
if [ "true" == "$ismaster" ]; then
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

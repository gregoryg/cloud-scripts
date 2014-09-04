#!/usr/bin/env bash

## dump the environment active at bootstrap script time
env > ~hadoop/bootstrap-env.txt

## is this the master node?
EMR_CONFIG_PATH='/mnt/var/lib/info/instance.json'
ismaster=`python -c 'import json; fp=open("'$EMR_CONFIG_PATH'","r"); print json.load(fp)["isMaster"]'`

# change directory to hadoop user home for duration of script
cd ~hadoop

# fix issues with Debian vs Red Hat
sudo ln -s /tmp /usr/


# Install tools
sudo apt-get update
sudo apt-get -y install locate htop tmux git

# copy DMX-h files from dmx S3 bucket
dmxrpm="dmexpress_7.14.3-2_amd64.deb"
echo Installing DMX-h
hadoop fs -copyToLocal s3://syncsortpocsoftware/"$dmxrpm" .

## install the pre-licensed DMX-h .rpm and set paths globally
sudo dpkg -i "$dmxrpm" && echo "Installed $dmxrpm"
echo '
DMXHOME=/usr/dmexpress
PATH=$PATH:$DMXHOME/bin
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DMXHOME/lib
export PATH LD_LIBRARY_PATH DMXHOME
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
## update slaves file on master node AFTER 
maprcli node list -columns hostname | cut -d' ' -f1 > ~hadoop/.versions/1.0.3/etc/hadoop/slaves
" > ~hadoop/setup-slaves.sh
chmod a+rx ~hadoop/setup-slaves.sh

fi

cd ~hadoop
## personal environment setup
    hadoop fs -copyToLocal  s3://syncsortpocsoftware/.tmux.conf .

# ## just to make s3 a little easier to deal with
#     echo Installing s3cmd
#     wget -O -  http://s3tools.org/repo/RHEL_6/s3tools.repo | sudo tee /etc/yum.repos.d/s3tools.repo
#     sudo yum -y install s3cmd
# fi

#    sudo updatedb&

    echo Done with bootstrap script



#!/bin/bash
#
# Copyright (c) 2014   Syncsort Inc.   Woodcliff Lake   New Jersey 07677
#
# Syncsort Proprietary and Confidential
#
# prepCluster.sh
#
# This script prepares the EMR cluster for 'hadoop' user
#
. $HOME/.bashrc

# Make /user/hadoop directory on HDFS
hadoop fs -mkdir -p /user/hadoop/


#!/bin/bash
bucket=sserpxemd
path=8.1.2/dmexpress-8.1.2-1.x86_64.rpm
wget --no-check-certificate -S -T 10 -t 5 http://$bucket.s3.amazonaws.com/$path
sudo rpm -i dmexpress-8.1.2-1.x86_64.rpm

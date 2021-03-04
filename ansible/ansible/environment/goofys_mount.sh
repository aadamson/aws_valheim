#!/bin/bash

USERNAME="$1"
BUCKET_NAME="$2"
MOUNT_POINT="/mnt/goofys/$BUCKET_NAME"

# Create mount point
mkdir -p $MOUNT_POINT

# Configure permissions on aws credentials (assume the file already exists)
chmod 600 /root/.aws/credentials 
chmod 700 /root/.aws

# Download goofys and symlink it into /bin
wget https://github.com/kahing/goofys/releases/download/v0.24.0/goofys -O /usr/sbin/goofys
chmod a+x /usr/sbin/goofys
ln -sf /usr/sbin/goofys /bin/mount.goofys

# Add an fstab entry and mount
echo "/bin/mount.goofys#$BUCKET_NAME $MOUNT_POINT fuse _netdev,allow_other,--file-mode=0644,--dir-mode=0777,--http-timeout=5m,--uid=$(id -u $USERNAME) 0 0" >> /etc/fstab
mount --all

#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: apt-aria2c
#     Desc: Use aria2c to download file 
#    Usage: apt-aria2c install|upgrade|dist-upgrade package_names
#  Example: apt-aria2c install firefox gimp
#           apt-aria2c upgrade
#           apt-aria2c dist-upgrade
# ----------------------------------------------------------------------------

if [ $# -eq 0 ]; then
    echo "./apt-aria2c install|upgrade|dist-upgrade package_names." 1>&2
    exit 1
fi

deb_path=$(mktemp -d)
cd "$deb_path"
apt-get -y --print-uris $@ | grep -E -o "http://[^\']+" | aria2c -c -i -

if [ $? -eq 0 ]; then
    cd /var/cache/apt/archives/
    sudo mv ${deb_path}/*.deb .
    if [ $? -eq 0 ]; then
        sudo apt-get $@
    fi
fi

rm -rf "$deb_path"

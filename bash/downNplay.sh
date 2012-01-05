#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: downNplay
#     Desc: Download and play media from Internetr
#    Usage: downNplay media_url
#     Note: This script can call by flashgot.
# ----------------------------------------------------------------------------

CACHE_DIR=~/
DELAY=3
PLAYER=smplayer

usage() {
    echo "usage: ./downNplay media_url"
}

if [ $# -lt 1 ]; then usage; exit; fi

if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
fi

cd $CACHE_DIR
url=$1
if [ -n "$2" ]; then
    file=$2
else
    file=`mktemp -u -p .`
fi
temp_file="$file.tmp"

if [ -e "$temp_file" ]; then
    echo ">>> Remove unfinish file"
    rm "$temp_file"
fi

if [ ! -e "$file" ]; then
    echo ">>> Start download $file"
    wget -U "mplayer" -c "$url" -O "$file" &
    sleep $DELAY
fi

if [ -e $file ]; then
    echo ">>> Start play $file"
    $PLAYER "$file"
fi

wget_pid=`pgrep "wget" | cut -d" " -f 1`
if [ -n "$wget_pid" ]; then
    echo ">>> Kill wget, pid is $wget_pid"
    kill $wget_pid
    mv "$file" "$temp_file"
fi

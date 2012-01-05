#!/bin/bash

cpuinfo=`/usr/bin/sar -u 1 3 | grep Average`
cpuusr=`echo $cpuinfo | awk '{print $3}'`
cpusys=`echo $cpuinfo | awk '{print $5}'`
upinfo=`uptime | cut -d \, -f 1`
echo $cpuusr
echo $cpusys
echo $upinfo
hostname

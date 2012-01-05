#!/bin/bash

meminfo=`/usr/bin/free |grep Mem`
memtotal=`echo $meminfo |awk '{print $2}'`
memused=`echo $meminfo |awk '{print $3}'`
upinfo=`uptime | cut -d \, -f 1`
echo $memtotal
echo $memused
echo $upinfo
hostname

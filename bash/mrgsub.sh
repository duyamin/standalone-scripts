#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: mrgsub
#     Desc: Merge mulit subtitles, each subtitle to one line
#    Usage: mrgsub.sh sub1.srt sub2.srt
#  Example: mrgsub.sh chs.srt eng.srt > chs-eng.srt
#           mplayer -overlapsub -sub chs-eng.srt
# ----------------------------------------------------------------------------

cat $* | fromdos | awk '{if ($0 ~ "^[1-9][0-9]*$|-->") {print $0} else {if ($0 ~ "^$") {print "\n"} else {printf("%s ",$0)}}}'

#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: clslrc
#     Desc: Clear contact message in lyric files
#    Usage: clslrc lrc_files
#  Example: clslrc *.lrc
# ----------------------------------------------------------------------------

sed -i -r '/^.*(qq|http|e-?mail).*$/Id' "$@"

#!/usr/bin/python
# -*- coding: utf8 -*-

# ----------------------------------------------------------------------------
#     Name: unquote
#     Desc: Unquote html text
#    Usage: unquote [quoted_file]
#  Example: unquote foobar.html
#           cat foobar.html | unquote
# ----------------------------------------------------------------------------

import urllib
import sys

def unquote(text):
    result = []
    for line in text.split("\n"):
        result.append(urllib.unquote(line))
    return "\n".join(result)

def usage():
    print "./unquote [quoted_file]"

def main():
    arg_num = len(sys.argv)
    
    if arg_num > 2:
        usage()
        exit(1)
        
    # read text
    if arg_num == 1:
        text = sys.stdin.read()
    else:
        file = open(sys.argv[0])
        text = file.read()
        file.close()
    result = unquote(text)
    
    # write text
    print result

if __name__ == '__main__':
    main()

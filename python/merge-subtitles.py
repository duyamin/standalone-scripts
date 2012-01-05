#!/usr/bin/python
# -*- coding: utf8 -*-

# ----------------------------------------------------------------------------
#     Name: merge-subtitles
#     Desc: Merge two subtitles
#    Usage: merge-subtitles sub1_file sub2_file out.ass
#  Example: merge_subtitles foobar.chs.srt foobar.eng.srt foobar.ass
# ----------------------------------------------------------------------------

import sys
import chardet
import aeidon

header = """[Script Info]
ScriptType: v4.00+
Collisions: Normal

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, BackColour, OutlineColour, Bold, Italic, Alignment, BorderStyle, Outline, Shadow, MarginL, MarginR, MarginV
Style: Default,WenQuanYi Micro Hei,16,&H00ffffff,&H00000000,&H00000000,0,0,2,1,1,0,20,20,20
Style: Alternate,WenQuanYi Micro Hei,9,&H00ffffff,&H00000000,&H00000000,0,0,2,1,1,0,20,20,20"""

def merge_subtitles(in_filename1, in_filename2, out_filename):
    # detect file encodings
    encoding1 = chardet.detect(open(in_filename1).read())['encoding']
    encoding2 = chardet.detect(open(in_filename2).read())['encoding']

    # create aeidon project
    project1 = aeidon.Project()
    project2 = aeidon.Project()
    project1.open_main(in_filename1, encoding1)
    project2.open_main(in_filename2, encoding2)

    # setup output format
    out_format = aeidon.files.new(aeidon.formats.ASS, out_filename, "utf_8")
    out_format.header = header
    header_lines = header.split('\n')
    defalut_margin_v = int(header_lines[6].split(',')[-1])
    alternate_fontsize = int(header_lines[7].split(',')[2])
    event_margin_v = defalut_margin_v + alternate_fontsize

    # motify event entries
    for subtitle in project1.subtitles:
        subtitle.main_text = subtitle.main_text.replace('\n', ' ')
        subtitle.ssa.margin_v = event_margin_v
    for subtitle in project2.subtitles:
        subtitle.main_text = subtitle.main_text.replace('\n', ' ')
        subtitle.ssa.style = 'Alternate'

    project1.subtitles.extend(project2.subtitles)
    project1.save_main(out_format)

def usage():
    print './merge-subtitles sub1_file sub2_file out.ass'

def main():
    if len(sys.argv) != 4:
        usage()
    else:
        merge_subtitles(*sys.argv[1:])

if __name__ == '__main__':
    main()

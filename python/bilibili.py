#!/usr/bin/python
# -*- coding: utf-8 -*-

# ----------------------------------------------------------------------------
#     Name: bilibili
#     Desc: 下载转换 bilibili.tv 的弹幕字幕为 ass 字幕
#    Usage: bilibili video_url|xml_file [ResX:ResY:FontSize:LineCount]
# ----------------------------------------------------------------------------

import sys
import re
from xml.dom.minidom import parseString
import requests
import aeidon

ASS_HEADER = """[Script Info]
ScriptType: v4.00+
Collisions: Normal
PlayResX: %s
PlayResY: %s

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, BackColour, OutlineColour, Bold, Italic, Alignment, BorderStyle, Outline, Shadow, MarginL, MarginR, MarginV
Style: NicoDefault,WenQuanYi Micro Hei,%s,&H00ffffff,&H00000000,&H00000000,0,0,2,1,1,0,20,20,20"""

class Bilibili:

    def __init__(self, xml_filename,
                       video_width=1280, video_height=768,
                       font_size=36, line_count=8):

        self.xml_filename = xml_filename # xml 文件名
        self.out_filename = xml_filename.replace('.xml', '.ass') # 输出 ass 文件名

        self.video_width = video_width # 视频宽度
        self.video_height = video_height # 视频高度
        self.font_size = font_size  # 字体大小
        self.line_count = line_count # 弹幕行数

        self.subtitle_lines = self.create_subtitle_lines()
        self.out_format = self.create_out_format()

    @staticmethod
    def get_comment_url(video_url):
        ''' 获得评论 url '''
        headers = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:9.0.1) Gecko/20100101 Firefox/9.0.1"}
        resp = requests.get(video_url, headers=headers)
        flashvars = re.findall('flashvars="([^"]+)"', resp.content)[0].split('=')[1]
        return 'http://comment.bilibili.tv/dm,' + flashvars

    @staticmethod
    def to_hms(seconds):
        ''' 时间轴转换 '''
        i, d = divmod(seconds, 1)
        m, s = divmod(i, 60)
        h, m = divmod(m, 60)
        return "%02d:%02d:%02d.%03d" % (h, m, s, d * 1000)

    def create_subtitle_lines(self):
        ''' 创建字幕行 '''
        with open(self.xml_filename) as xml_file:
            xml_text = xml_file.read()
        lines = []
        dom = parseString(xml_text)
        for node in dom.getElementsByTagName('d'):
            # TODO 解析更多样式
            start_seconds = float(node.attributes.get('p').value.split(',')[0])
            text = node.childNodes[0].data
            line = (start_seconds, text)
            lines.append(line)
        lines.sort()
        return lines

    def create_out_format(self):
        ''' 创建 aeidon 库的保存格式对象 '''
        out_format = aeidon.files.new(aeidon.formats.ASS, self.out_filename, "utf_8")
        out_format.header = ASS_HEADER % (self.video_width, self.video_height, self.font_size)
        return out_format

    def subtitle_strategy(self, i, line):
        ''' 弹幕位置策略，看个人喜好了 '''
        start_seconds, text = line
        text_length = float(len(text))
        if text_length < 5:
            end_seconds = start_seconds + 4 + (text_length / 1.5)
        elif text_length < 12:
            end_seconds = start_seconds + 4 + (text_length / 2)
        else:
            end_seconds = start_seconds + 4 + (text_length / 2.5)
        x1 = self.video_width + (self.font_size * text_length) / 2
        x2 = -(self.font_size * text_length) / 2
        y = (i % 8) * self.font_size
        y1 , y2 = y, y
        return (start_seconds, end_seconds, x1, y1, x2, y2, text)

    def save(self):
        ''' 保存输出 '''
        project = aeidon.Project()
        for i, line in enumerate(self.subtitle_lines, 1):
            (start_seconds, end_seconds,
             x1, y1,
             x2, y2,
             text) = self.subtitle_strategy(i, line)

            subtitle = aeidon.Subtitle()
            subtitle.ssa.style = 'NicoDefault'
            subtitle.ssa.layer = 3
            subtitle.main_text = '{\\move(%d, %d, %d, %d)}%s' % (x1, y1, x2, y2, text)
            subtitle.start = Bilibili.to_hms(start_seconds)
            subtitle.end = Bilibili.to_hms(end_seconds)

            project.subtitles.append(subtitle)

        project.save_main(self.out_format)

def main():
    # 如果是个 url 地址，就下载 xml
    if sys.argv[1].startswith('http://'):
        video_url = sys.argv[1]
        comment_url = Bilibili.get_comment_url(video_url)
        text = requests.get(comment_url).content
        xml_filename = '%s.xml' % video_url.split('/')[-2][2:]
        with open(xml_filename, 'w') as xml_file:
            xml_file.write(text)
    else:
        xml_filename = sys.argv[1]

    if len(sys.argv) == 3:
        (video_width, video_height,
         font_size, line_count) = map(int, sys.argv[2].split(':'))
        bilibili = Bilibili(xml_filename,
                            video_width, video_height,
                            font_size, line_count)
    else:
        bilibili = Bilibili(xml_filename)

    bilibili.save()

def usage():
    print 'usage: ./bilibili.py video_url|xml_file [ResX:ResY:FontSize:LineCount]'

if __name__ == '__main__':
    if len(sys.argv) == 1:
        usage()
        exit(1)
    main()

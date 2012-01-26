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

class Subtitle():

    STYLE_SCROLL = 1
    STYLE_STATIC = 5
    FLASH_FONT_SIZE = 25 # 官方 flash 播放器的默认字体

    def __init__(self, index, attributes, text,
                 video_width=1280, video_height=768,
                 default_font_size=36, line_count=6):

        self.index = index # 字幕序号
        self.attributes = attributes # xml 的属性
        self.text = text # 无样式文本

        self.video_width = video_width
        self.video_height = video_height
        self.default_font_size = default_font_size
        self.line_count = line_count

        self.text_length = self.init_text_length()
        self.start_seconds = self.init_start_seconds()
        self.color = self.init_color()
        self.style = self.init_style()

        self.start = self.init_start()
        self.end = self.init_end()
        self.font_size = self.init_font_size()
        (self.x1, self.y1,
         self.x2, self.y2) = self.init_position();
        self.styled_text = self.init_styled_text()

    @staticmethod
    def to_hms(seconds):
        ''' 时间轴转换 '''
        if seconds < 0:
            return '00:00:00.000'

        i, d = divmod(seconds, 1)
        m, s = divmod(i, 60)
        h, m = divmod(m, 60)
        return "%02d:%02d:%02d.%03d" % (h, m, s, d * 1000)

    def init_text_length(self):
        return float(len(self.text))

    def init_start_seconds(self):
        return float(self.attributes[0])

    def init_start(self):
        return Subtitle.to_hms(self.start_seconds)

    def init_end(self):
        if self.style == Subtitle.STYLE_STATIC:
            return Subtitle.to_hms(self.start_seconds + 4)

        if self.text_length < 5:
            end_seconds = self.start_seconds + 4 + (self.text_length / 1.5)
        elif self.text_length < 12:
            end_seconds = self.start_seconds + 4 + (self.text_length / 2)
        else:
            end_seconds = self.start_seconds + 10
        return Subtitle.to_hms(end_seconds)

    def init_color(self):
        return hex(int(self.attributes[3])).upper()[2:]

    def init_style(self):
        return int(self.attributes[1])

    def init_font_size(self):
        return int(self.attributes[2]) - Subtitle.FLASH_FONT_SIZE + self.default_font_size

    def init_position(self):
        if self.style == Subtitle.STYLE_SCROLL:
            x1 = self.video_width + (self.font_size * self.text_length) / 2
            x2 = -(self.font_size * self.text_length) / 2
            y = (self.index % self.line_count) * self.font_size
            return (x1, y, x2 , y)
        else:
            x = self.video_width / 2 
            y = 1
            return (x, y, x, y)

    def init_styled_text(self, ):
        if self.color == 'FFFFFF':
            color_markup = ""
        else:
            color_markup = "\\c&H%s" % self.color
        if self.font_size == self.default_font_size:
            font_size_markup = ""
        else:
            font_size_markup = "\\fs%d" % self.font_size
        if self.style == Subtitle.STYLE_SCROLL:
            style_markup = "\\move(%d, %d, %d, %d)" % (self.x1, self.y1, self.x2, self.y2)
        else:
            style_markup = "\\a6\\pos(%d, %d)" % (self.x1, self.y1)
        return "{%s}%s" % ("".join([style_markup, color_markup, font_size_markup]), self.text)

class Bilibili:

    def __init__(self, xml_filename,
                 video_width=1280, video_height=768,
                 default_font_size=36, line_count=6):
        self.xml_filename = xml_filename # xml 文件名
        self.out_filename = xml_filename.replace('.xml', '.ass') # 输出 ass 文件名

        self.video_width = video_width # 视频宽度
        self.video_height = video_height # 视频高度
        self.default_font_size = default_font_size # 字体大小
        self.line_count = line_count # 弹幕行数

        self.subtitles = self.create_subtitles()
        self.out_format = self.create_out_format()

    @staticmethod
    def get_comment_url(video_url):
        ''' 获得评论 url '''
        headers = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:9.0.1) Gecko/20100101 Firefox/9.0.1"}
        resp = requests.get(video_url, headers=headers)
        flashvars = re.findall('flashvars="([^"]+)"', resp.content)[0].split('=')[1]
        return 'http://comment.bilibili.tv/dm,' + flashvars

    def create_subtitles(self):
        ''' 创建字幕 '''
        with open(self.xml_filename) as xml_file:
            xml_text = xml_file.read()

        entries = []
        dom = parseString(xml_text)
        for node in dom.getElementsByTagName('d'):
            attributes = node.attributes.get('p').value.split(',')
            text = node.childNodes[0].data
            start_seconds = float(attributes[0])
            entry = (start_seconds, attributes, text)
            entries.append(entry)
        entries.sort()

        subtitles = []
        for i, entry in enumerate(entries):
            start_seconds, attributes, text = entry
            subtitle = Subtitle(i, attributes, text,
                                self.video_width, self.video_height,
                                self.default_font_size, self.line_count)
            subtitles.append(subtitle)
        return subtitles

    def create_out_format(self):
        ''' 创建 aeidon 库的保存格式对象 '''
        out_format = aeidon.files.new(aeidon.formats.ASS, self.out_filename, "utf_8")
        out_format.header = ASS_HEADER % (self.video_width, self.video_height, self.default_font_size)
        return out_format

    def save(self):
        ''' 保存输出 '''
        project = aeidon.Project()
        for subtitle in self.subtitles:
            aeidon_subtitle = aeidon.Subtitle()
            aeidon_subtitle.ssa.style = 'NicoDefault'
            aeidon_subtitle.ssa.layer = 3
            aeidon_subtitle.main_text = subtitle.styled_text
            aeidon_subtitle.start = subtitle.start
            aeidon_subtitle.end = subtitle.end
            project.subtitles.append(aeidon_subtitle)
        project.save_main(self.out_format)

def main():
    # 如果是个 url 地址，就下载 xml
    if sys.argv[1].startswith('http://'):
        video_url = sys.argv[1]
        comment_url = Bilibili.get_comment_url(video_url)
        print comment_url
        text = requests.get(comment_url).content
        xml_filename = '%s.xml' % video_url.split('/')[-2][2:]
        with open(xml_filename, 'w') as xml_file:
            xml_file.write(text)
    else:
        xml_filename = sys.argv[1]

    if len(sys.argv) == 3:
        settings = map(int, sys.argv[2].split(':'))
        bilibili = Bilibili(xml_filename, *settings)
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

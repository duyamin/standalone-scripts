#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: omsc
#     Desc: Opera Mini Server Changer
#    Usage: omsc.sh jar_file
#  Example: omsc.sh opera-mini.jar
# ----------------------------------------------------------------------------

usage() {
	echo "用法：./omsc opera-mini.jar"
	echo "注：目前仅支持Opera Mini 4.2国际版"
}

# 一些常量
SERVER="http://server4.operamini.com:80/"
CLASS="a.class"

# 检查用到的工具是否存在
apps=(unzip zip grep awk sed bc xxd dd wc)
for i in ${apps[@]}; do 
    which $i > /dev/null
    if [ $? -eq 1 ]; then miss+="$i "; fi
done
if [ "$miss" != "" ]; then 
     echo "系统缺少以下工具，请先安装再重新运行。"
     echo $miss
     exit
fi

# 命令行参数
if [ $# -ne 1 ]; then usage; exit; fi
if [ ! -e $1 ]; then echo "错误，该文件不存在" >&2; exit; fi
input=$1
source_dir=$PWD

# 开始处理，打印标题
echo "------------------------------------------------"
echo " Opera Mini Server Changer v0.1"
echo " 需要配合 opm-server-mirror 使用"
echo " http://code.google.com/p/opm-server-mirror/"
echo "------------------------------------------------"

# 建立临时目录和解压jar
echo "正在解压 jar 文件..."
mkdir /tmp/$$
cd /tmp/$$
unzip $source_dir/$input > /dev/null

# 输入用户自定义代理
echo "请输入你的opm-server-mirror代理网页php文件地址"
echo "例如:http://www.yoursite.com:80/folder_if_any/index.php"
read -p "代理地址:" proxy_url

# 查找class文件里官方服务器地址的偏移量
echo "正在处理 java class 文件..."
length=`echo -n $proxy_url | wc -m`
if [ "$length" -lt 10 ]
then length=`printf "%02d" $length`
else length=`echo "obase=16; ibase=10; $length" | bc`
fi
length=`echo -n $length | xxd -r -p`
proxy_url=`echo -n $proxy_url | iconv -t ascii`
position=`grep -o -a -b $SERVER $CLASS | sed 's/:/ /'`
url_start=`echo -n $position | awk '{print $1}'`
url_start=`echo "$url_start - 1" | bc`
url_length=`echo -n $position | awk '{print $2}' | wc -m`
url_end=`echo $url_length + $url_start | bc`

# 建立新的class文件
dd if=$CLASS bs=1 count=$url_start > $CLASS.tmp 2> /dev/null
echo -n $length$proxy_url >> $CLASS.tmp
dd if=$CLASS bs=1 skip=$url_end >> $CLASS.tmp 2> /dev/null
mv $CLASS.tmp $CLASS

# 打包回jar并移动回原始目录
echo "正在创建新的 jar 文件..."
output=${input%.jar}-mod.jar
zip -r $output * > /dev/null
mv $output $source_dir
rm -r /tmp/$$

# 修改完成
echo "恭喜，修改成功！"
echo "已修改文件为 $output"
exit

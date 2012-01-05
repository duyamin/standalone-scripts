#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: msplitter
#     Desc: Split video files with mencoder
#    Usage: msplitter {-n number | -l length | -p position1,position2...} \
#           [-t filetype] [-o output_folder] [-a "mencoder_arguments"] \
#           -f video_file [-m]
#  Example: msplitter -l 1:23 -f file.avi
#           msplitter -n 4 -f file.avi
#           msplitter -p 12,3:4,5:6 -f file.avi
#           msplitter -n 4 -f file.avi -o split/ -a "-oac lavc -ovc lavc"
#           msplitter -n 4 -f file.avi -m
#           msplitter -n 4 -f file.avi -a "-oac lavc -ovc lavc" -m
#     Note: You must specified split method and file, method can be number,
#           length or position, number and can use together.
#           Number must a integer. Length is a time format, for example, two
#           minutes can express by "120" or "2:0" or "1:60". position also
#           follow by time format like length, but it can separate by comma.
#           Deafult filetype is avi. default ouput folder is working folder,
#           default mencoder arguments is "-oac copy -ovc copy".
#           If "-m" is not given, just print the command, you can check it,
#           or reditect it to file for edit. If is given, it will directly
#           call mencoder to split files.
# ----------------------------------------------------------------------------

# convert time format to seconds, like this: 1:2:3 --> 3723
function time2seconds() {
    _time=($(echo "${1}" | tr ":" " "))
    _length=${#_time[@]}
    _seconds=0
    for i in `seq $_length`; do 
        _part=$(echo "${_time[$_length  - $i]} * 60^($i - 1)" | bc)
        _seconds=$(echo "$_seconds + $_part" | bc);
    done
    echo $_seconds
}

# convert seconds to time foramt
function seconds2time() {
    _seconds=$1
    _h=$(echo "$_seconds / 60^2" | bc)
    _m=$(echo "($_seconds - $_h * 60^2) / 60" | bc)
    _s=$(echo "$_seconds - $_h * 60^2 - $_m * 60^1" | bc)
    printf "%02d:%02d:%05.2f" $_h $_m $_s
}

# print result or call mencoder
function resultHandler(){
    _cmd="-ss $startpos -endpos $endpos -o ${output}${filename}_${i}.${filetype} $file" 
    _cmd_long="mencoder $arguments $_cmd"
    if [ "$mencoder" == "true" ]; then
        # check whether specified output directory exist, if not create it
        if [ ! -d "$output" ]; then
            mkdir -p $output
        fi
        # run it
        $_cmd_long
    else
        # just print
        if [ -n "$arguments" ]; then
            echo $_cmd_long
        else
            echo $_cmd
        fi
    fi
}

### program start ###

# get commmand line arguments
while getopts ':n:l:p:t:o:f:a:m' arg; do
    case $arg in
        n)
            number=$OPTARG ;;
        l)
            length=$OPTARG ;;
        p)
            positions=$OPTARG ;;
        t)
            filetype=$OPTARG ;;
        o)
            output=$OPTARG ;;
        a)
            arguments=$OPTARG ;;
        f)
            file=$OPTARG ;;
        m)
            mencoder=true ;;
    esac
done

### check arguments ###

# check whether specified file and file exist
if [ -z "$file" -o ! -f "$file" ]; then
    echo "Error: no file specified or file not exist." 2>&1
    exit 1
fi

# user must chose split by number or length
if [ -z "$number" -a -z "$length" -a -z "$positions" ]; then
    echo "Error: no number, length or positions specified." 2>&1
    exit 2
fi

# check split method
if [ -n "$positions" -a \( -n "$number" -o -n "$length" \) ]; then
    echo "Error: positions cann't not use with length or positions." 2>&1
    exit 3
fi

### setup default value ###

# if no output directory specified, use working folder
if [ -z "$output" ]; then
    output="./"
else 
    # add "/" to ouput directory path
    output=$(echo "$output" | sed 's/\/\?$/\//')
fi

# if not filetype specified, use avi
if [ -z "$filetype" ]; then
    filetype="avi"
fi

# if no mencoder arguments, use copy
if [ -z "$arguments" ]; then
    arguments="-oac copy -ovc copy"
fi

### start split ###

video_length=$(mplayer -identify -frames 0 $file 2>/dev/null | grep ID_LENGTH | cut -d "=" -f 2)
filename=$(echo $file | sed "s/\/\?\.[^.]\+$//")

# split by number or length
if [ -n "$number" -o -n "$length" ]; then
    # split by length 
    if [ -z "$number" -a -n "$length" ]; then
        length=$(time2seconds $length)
        number=$(echo "$video_length / $length + 1" | bc)
    # split by number
    elif [ -n "$number" -a -z "$length" ]; then
        length=$(echo "$video_length / $number + 1" | bc)
    # split by number and length
    else
        length=$(time2seconds $length)
        max_number=$(echo "$video_length / $length + 1" | bc)
        if [ $number -gt $max_number ]; then
            number=$max_number
        fi
    fi

    # calc mencoder options
    for i in `seq $number`; do
        startpos=$(seconds2time $(echo "$length * ($i - 1)" | bc))
        endpos=$(seconds2time $length)
        resultHandler
    done
# split by positions 
elif [ -n "$positions" ]; then
    positions=($(echo "00,${positions},${video_length}" | tr "," " "))
    # convert all position to seconds format
    for i in `seq ${#positions[@]}`; do
        positions[$i - 1]=$(time2seconds ${positions[$i - 1]})
    done
    # calc mencoder options
    for i in `seq $((${#positions[@]} - 1))`; do
        startpos=$(seconds2time ${positions[$i -1]})
        endpos=$(echo "${positions[$i]} - ${positions[$i - 1]}" | bc)
        endpos=$(seconds2time $endpos)
        resultHandler
    done
fi

#!/bin/bash

# ----------------------------------------------------------------------------
#     Name: rmfxel
#     Desc: Remove Firefox extension locales
#    Usage: rmfxel [-n] [-k locales] -d directory
#  Example: rmfxel -d ~/.mozilla/firefox/abcdefgh.default/extensions/
#           rmfxel -d extensions/extension_subdirectory
#           rmfxel -n -k zh-CN,zh-TW -d extensions/
# ----------------------------------------------------------------------------

function usage () {
   echo "Usage: ./rmfxel [-n] [-k locales] -d directory"
   echo "    -n - nobackup"
   echo "    -k - keep locales, e.g zh-CN,zh-TW"
   echo "    -d - extension directory"
}

# convert bytes to human readable format
function toHumanReadable() {
    if [ -n "$1" ]; then
        number=$1
    else
        number=$(cat)
    fi
    if [ -z $number ]; then
        return 1
    fi
    statements="scale=2;
                if ( $number < 1024^1 ) {
                    print $number,\"B\"
                } else if ( $number < 1024^2 ) {
                    print $number / 1024^1,\"K\"
                } else if ( $number < 1024^3 ) {
                    print $number / 1024^2,\"M\"
                } else if ( $number <1024^4 ) {
                    print $number / 1024^3,\"G\"
                } else {
                    print $number / 1024^4,\"T\"
                }"
    echo $statements | bc 
}

# get the all regular files size in directory
function getDirectorySize() {
    if [ -z "$1" ]; then
        echo 0
    else
        find $1 -type f -printf "%s+" | sed 's/+$/\n/' | bc
    fi
}

# backup directory
function backupDirectory() {
    # use tar -cf directory_name.tar -C path directory, because
    # tar -cf extensions.tar ~/.mozilla/firefox/abcdefgh.default/extensions
    # the tar file root is "home", and
    # tar -cf extensions.tar -C ~/.mozilla/firefox/abcdefgh.default extensions
    # the tar file root is "extensions" 
    tarArgs=$(readlink -f $1 | sed -e 's/\/\?$//' -e 's/\/\([^\/]\+\)$/ \1/')
    tar -cf $2 -C $tarArgs
}

# remove the locales in current folder
function removeLocale() {

    # get locale line, save as an array, two element as a locale group
    # like: ["en-US", "locale/en-US", "zh-CN", "locale/zh-CN", name, path]
    _localeLines=($(grep '^locale\>' "chrome.manifest" | awk '{print $3 " " $4}'))

    # setup for loop length
    _length=$((${#_localeLines[@]} - 1))

    # temp file to save remove path
    _removeList=$(tempfile)

    # save the path of jar file
    _jarFile=""

    for i in `seq 0 2 $_length`; do

        # the locale name
        _localeName=${_localeLines[$i]}

        # need to remove newline "\r" and sub directory in local name folder, if has either.
        # like: locale/en-US/helloworld/\r -> locale/en-US/
        _localePath=$(echo ${_localeLines[$i+1]} | sed -e 's/\r//g' -e 's/\('"\<$_localeName\>"'\/\).*/\1/')

        # if not in keep locales list, skip it
        echo "$keepLocales" | grep -iq "\<${_localeName}\>" > /dev/null
        if [ $? -eq 0 ]; then
            echo "      keep $_localeName -> $_localePath"
            continue
        fi

        # begin to remove
        printf "    remove %5s " "$_localeName"

        # remove the line in chrmoe.manifest
        sed -i '/^locale\>.\+'"\<${_localeName}\>"'/d' "chrome.manifest"

        # check if is jar file 
        echo "$_localePath" | grep -iq "^jar:"
        if [ $? -eq 0 ]; then
            _jarNfolder=($(echo $_localePath | sed -e 's/^jar://' -e 's/jar!\//jar /'))
            echo "-> ${_jarNfolder[@]}"
            _jarFile=${_jarNfolder[0]}
            echo "${_jarNfolder[1]}" >> $_removeList
        else
            echo "-> $_localePath"
            echo "$_localePath" >> $_removeList
        fi
    done

    # remove it, if _jarFile is empty, just call rm to remove
    if [ -z "$_jarFile" ]; then
        cat "$_removeList" | xargs -r rm -r
    else
        # locale files in jar file, call 7zip to delete them
        7z d -tzip -i@"$_removeList" "$_jarFile" > /dev/null
    fi
    
    # temp file not need any more
    rm $_removeList
}

### program start ###

if [ $# -eq 0 ]; then usage; exit; fi

# get commmand line arguments
while getopts 'd:k:n' arg; do
    case $arg in
        d)
            directory=$OPTARG ;;
        k)
            keepLocales=$OPTARG ;;
        n)
            nobackup=true ;;
    esac
done

### check arguments ###

# check whether specified directory and directory exist
if [ -z "$directory" -o ! -d "$directory" ]; then
    echo "Error: no directory specified or directory not exist." 2>&1
    exit 1
fi

### setup default value ###

# the locale will not remove
# get default locale and convert format, en_US.utf8 -> en-US
defaultLocale=$(echo $LANG | sed -e 's/\..\+//' -e 's/_/-/')
if [ "$defaultLocale" == "en-US" ]; then
    keepLocales=en-US,$keepLocales
else
    keepLocales=en-US,$defaultLocale,$keepLocales
fi
#echo "Keep locales are: $keepLocales"

# make a backup
if [ "$nobackup" != "true" ]; then
    echo "Backup $directory"
    tarName=$(basename $directory)
    # check backup file exist
    if [ -f "${tarName}.tar" ]; then
        read -p "    backup file ${tarName}.tar already exist, replace it ? (y/n/a): " response
        if [ "$response" == "y" ]; then
            backupDirectory $directory ${tarName}.tar
            echo "    backup file ${tarName}.tar has replaced"
        elif [ "$response" == "n" ]; then
            echo "    skip replace backup file"
        else
            echo "Abort, exit"
            exit
        fi
    else
        backupDirectory $directory ${tarName}.tar
        echo "    backup file ${tarName}.tar has created"
    fi
fi

### start cleanup ###

# save source directory size
source_pwd=$(pwd)
source_size=$(getDirectorySize $directory | toHumanReadable)

# check whether a extension directory or it is parent directory
cd $directory
if [ -f install.rdf ]; then
    directories=./
else
    directories=./*
fi

for i in $directories; do
    echo -n "Cleaning: $i - "
    cd $i
    # check it again for safe
    if [ -f install.rdf ]; then
        grep -i -m 1 "em:name" install.rdf | sed -e 's/^[^>]\+>//g' -e 's/<.*$//'
        removeLocale
    else
        echo "Warring: $i is not a extension folder, skip it"
    fi
    cd .. 
done

# display motified size
cd $source_pwd
modtified_size=$(getDirectorySize $directory | toHumanReadable)
echo "Directory total files size change"
echo "    before: $source_size"
echo "     after: $modtified_size"
echo "All Done"

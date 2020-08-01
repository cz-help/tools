#!/bin/bash

version=${1:-11}
arch=${2:-x64}
use_timestamp=${3:-0}

[ -e /ramdisk ] && tmp_dir="/ramdisk" || tmp_dir="/tmp"

echo "Getting URL of the file"
file_url="$(curl -s  https://jdk.java.net/${version}/ | grep "linux-${arch}_bin" | grep -v sha256 | sed "s/.*href=\"\(http[^\"]*\).*/\1 /" | head -1 | tr -d "[[:space:]]" )"

if [ -z ${file_url} ] 
then
	echo " . . not current version / checking archive for latest requested available version"
	file_url="$(curl -s  https://jdk.java.net/archive/ | grep "linux-${arch}_bin" | grep -v sha256 | grep openjdk-${version} | sed "s/.*href=\"\(http[^\"]*\).*/\1 /" | head -1 | tr -d "[[:space:]]" )"
	if [ -z ${file_url} ] 
	then
		echo "Cannot get URL for latest ${version} release" 
		exit 1
	fi
fi
file_name="$(basename ${file_url})"

echo " . . . done : ${file_name} ( ${file_url} )"
echo

if [ ! -e ${tmp_dir}/${file_name} ] 
then
		echo "Downloading ${file_name} to ${tmp_dir}/${file_name}"
		echo
		curl -o ${tmp_dir}/${file_name} ${file_url}
		echo
fi
if [ ! -e ${tmp_dir}/${file_name}.sha256 ] 
then
		echo "Downloading ${file_name}.sha256 to ${tmp_dir}/${file_name}.sha256"
		echo
		curl -o ${tmp_dir}/${file_name}.sha256 ${file_url}.sha256
		echo
fi

if [ "$(<${tmp_dir}/${file_name}.sha256)" == "$(sha256sum ${tmp_dir}/${file_name} | sed "s/\([^[:space:]]*\).*/\1/" | tr -d [[:space:]])" ]
then
	echo -n "The file is locally available : "
	du -sh ${tmp_dir}/${file_name} | sed "s/^\([^[:space:]]*\)[[:space:]]*\(.*\)$/\2 (\1)/"
	echo
else
	echo "The control checksum on file ${file_name} does not pass"
	exit 2
fi

[ ${use_timestamp} -eq 1 ] && work_timestamp="$(date +%s)/" || work_timestamp=""
work_dir="${work_timestamp}$(tar -tzf ${tmp_dir}/${file_name} | head -1 | sed "s/^\([^\/]*\)\/.*/\1/")"
[ ! -e ${tmp_dir}/${work_timestamp} ] && mkdir ${tmp_dir}/${work_timestamp}

echo "Unpacking ${tmp_dir}/${file_name} to ${tmp_dir}/${work_timestamp}"
echo

[ -e ${tmp_dir}/${work_dir} ] && local_cleanup=0 || local_cleanup=1
tar -xz -C ${tmp_dir}/${work_timestamp} -f ${tmp_dir}/${file_name}
JAVA_HOME=${tmp_dir}/${work_dir}
PATH=${tmp_dir}/${work_dir}/bin:${PATH}

echo "Preparing \"JRE\" environment (using jlink aplication) to ${tmp_dir}/${work_dir}-jre )" 
echo jlink --no-header-files --no-man-pages --compress=2 --add-modules ALL-MODULE-PATH  --output ${tmp_dir}/${work_dir}-jre

jlink --no-header-files --no-man-pages --compress=2 --add-modules ALL-MODULE-PATH  --output ${tmp_dir}/${work_dir}-jre

echo
cat ${tmp_dir}/${work_dir}-jre/release
echo
echo -n "\"JRE\" environment is ready on location : "
du -sh ${tmp_dir}/${work_dir}-jre | sed "s/^\([^[:space:]]*\)[[:space:]]*\(.*\)$/\2 (\1)/"
[ ${local_cleanup} -eq 1 ] && rm -rf ${tmp_dir}/${work_dir}

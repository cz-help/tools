#!/bin/sh

version=${1:-11}
arch=${2:-x64}
use_timestamp=${3:-0}

[ "${getCmd}" == "" -a $( which curl | wc -l) -gt 0 ] && getCmd="curl"
[ "${getCmd}" == "" -a $( which wget | wc -l) -gt 0 ] && getCmd="wget"

if [ "%{getCmd}" == "" ]
then
	echo "Cannot find the way for downloading data..."
		exit 99
fi

function getData {
	localGetDataOption=""
	case ${getCmd} in
		curl)
			[ ${2:-0} -eq 1 ] && localGetDataOption="${localGetDataOption} -s"
			[ "${3}" != "" ] && localGetDataOption="${localGetDataOption} -o ${3}"
			echo curl ${localGetDataOption} ${1}
			curl ${localGetDataOption} ${1}
			;;
		wget)
			[ ${2:-0} -eq 1 ] && localGetDataOption="${localGetDataOption} -q"
			[ "${3}" == "" ] && localGetDataOption="${localGetDataOption} -O -" || localGetDataOption="${localGetDataOption} -O ${3}"
			echo wget ${localGetDataOption} ${1}
			wget ${localGetDataOption} ${1}
			;;
	esac
}

[ -e /ramdisk ] && tmp_dir="/ramdisk" || tmp_dir="/tmp"

echo "Getting URL of the file"
file_url="$( getData https://jdk.java.net/${version}/ 1 | grep "linux-${arch}_bin" | grep -v sha256 | sed "s/.*href=\"\(http[^\"]*\).*/\1 /" | head -1 | tr -d "[[:space:]]" )"

if [ -z ${file_url} ] 
then
	echo " . . not current version / checking archive for latest requested available version"
	file_url="$( getData  https://jdk.java.net/archive/ 1 | grep "linux-${arch}_bin" | grep -v sha256 | grep openjdk-${version} | sed "s/.*href=\"\(http[^\"]*\).*/\1 /" | head -1 | tr -d "[[:space:]]" )"
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
		getData ${file_url} 0 ${tmp_dir}/${file_name}
		echo
fi
if [ ! -e ${tmp_dir}/${file_name}.sha256 ] 
then
		echo "Downloading ${file_name}.sha256 to ${tmp_dir}/${file_name}.sha256"
		echo
		getData ${file_url}.sha256 0 ${tmp_dir}/${file_name}.sha256
		echo
fi

if [ "$(cut -c 1-64 ${tmp_dir}/${file_name}.sha256)" == "$(sha256sum ${tmp_dir}/${file_name} | cut -c 1-64)" ]
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
[ "${getJREdir}" == "" ] && jre_dir="${work_dir}-jre" || jre_dir="${getJREdir}"
[ ! -e ${tmp_dir}/${work_timestamp} ] && mkdir ${tmp_dir}/${work_timestamp}

echo "Unpacking ${tmp_dir}/${file_name} to ${tmp_dir}/${work_timestamp}"
echo

[ -e ${tmp_dir}/${work_dir} ] && local_cleanup=0 || local_cleanup=1
tar -xz -C ${tmp_dir}/${work_timestamp} -f ${tmp_dir}/${file_name}
JAVA_HOME=${tmp_dir}/${work_dir}
PATH=${tmp_dir}/${work_dir}/bin:${PATH}

echo "Preparing \"JRE\" environment (using jlink aplication) to ${tmp_dir}/${jre_dir} )" 
echo jlink --no-header-files --no-man-pages --compress=2 --add-modules ALL-MODULE-PATH  --output ${tmp_dir}/${jre_dir}

jlink --no-header-files --no-man-pages --compress=2 --add-modules ALL-MODULE-PATH  --output ${tmp_dir}/${jre_dir}

echo
cat ${tmp_dir}/${jre_dir}/release
echo
echo -n "\"JRE\" environment is ready on location : "
du -sh ${tmp_dir}/${jre_dir} | sed "s/^\([^[:space:]]*\)[[:space:]]*\(.*\)$/\2 (\1)/"
[ ${local_cleanup} -eq 1 ] && rm -rf ${tmp_dir}/${work_dir}

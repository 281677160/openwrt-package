#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001

rm -f /tmp/cloud_*_version
if [ ! -f /bin/AutoUpdate.sh ];then
	echo "未检测到 /bin/AutoUpdate.sh" > /tmp/cloud_nightly_version
	echo "未检测到 /bin/AutoUpdate.sh" > /tmp/cloud_stable_version
	exit
fi
CURRENT_Device="$(awk 'NR==3' /etc/openwrt_info)"
CURRENT_Source="$(awk 'NR==4' /etc/openwrt_info)"
Github="$(awk 'NR==2' /etc/openwrt_info)"
[[ -z "${Github}" ]] && exit
Author="${Github##*com/}"
Github_Tags="https://api.github.com/repos/${Author}/releases/latest"

function Stable(){
    Github_Tags="https://api.github.com/repos/${Author}/releases/tags/openwrt-stable"
    wget -q ${Github_Tags} -O - > /tmp/stable_Tags
    GET_Version_Type="stable"
    GET_FullVersion=$(cat /tmp/stable_Tags | egrep -o "openwrt-${CURRENT_Source}-${CURRENT_Device}-${GET_Version_Type}-[0-9]+.[0-9]+.[0-9]+.[0-9]+.[a-z]+.[a-z]+" | awk 'END {print}')
    GET_Ver="${GET_FullVersion#*${CURRENT_Device}-}"
    GET_Stable="${GET_Ver:0:20}"
    echo $GET_Stable
}

function Nightly(){
    Github_Tags="https://api.github.com/repos/${Author}/releases/tags/update_Firmware"
    wget -q ${Github_Tags} -O - > /tmp/Firmware_Tags
    GET_Version_Type="Firmware"
    GET_FullVersion=$(cat /tmp/Firmware_Tags | egrep -o "openwrt-${CURRENT_Source}-${CURRENT_Device}-${GET_Version_Type}-[0-9]+.[0-9]+.[0-9]+.[0-9]+.[a-z]+.[a-z]+" | awk 'END {print}')
    GET_Ver="${GET_FullVersion#*${CURRENT_Device}-}"
    GET_Nightly="${GET_Ver:0:22}"
    echo $GET_Nightly
}

GET_Nightly_Version=$(Nightly)
GET_Stable_Version=$(Stable)

[[ -z "${GET_Stable_Version}" ]] && GET_Stable_Version="未知"
echo "${GET_Stable_Version}" > /tmp/cloud_stable_version
CURRENT_Version="$(awk 'NR==1' /etc/openwrt_info)"
if [ ! -z "${GET_Nightly_Version}" ];then
	if [[ "${CURRENT_Version}" == "${GET_Nightly_Version}" ]];then
		Checked_Type="已是最新"
	else
		Checked_Type="可更新"
	fi
	echo "${GET_Nightly_Version} [${Checked_Type}]" > /tmp/cloud_nightly_version
else
	echo "未知" > /tmp/cloud_nightly_version
fi
exit

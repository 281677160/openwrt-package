#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001

rm -f /tmp/cloud_*_version
if [ ! -f /bin/AutoUpdate.sh ];then
	echo "未检测到 /bin/AutoUpdate.sh" > /tmp/cloud_nightly_version
	echo "未检测到 /bin/AutoUpdate.sh" > /tmp/cloud_stable_version
	exit
fi
CURRENT_DEVICE="$(awk 'NR==3' /etc/openwrt_info)"
Github="$(awk 'NR==2' /etc/openwrt_info)"
[[ -z "${Github}" ]] && exit
Author="${Github##*com/}"
Github_Tags="https://api.github.com/repos/${Author}/releases/latest"

function Stable(){
    Github_Tags="https://api.github.com/repos/${Author}/releases/tags/openwrt-stable"
    wget -q ${Github_Tags} -O - > /tmp/stable_Tags
    if [[ $CURRENT_DEVICE == x86-64 ]];then
    	GET_FullVersion=$(cat /tmp/stable_Tags | egrep -o "openwrt-${CURRENT_DEVICE}-stable-[0-9]+.[0-9]+.[0-9]+.[0-9]+.[a-z]+.[a-z]+" | awk 'END {print}')
    	GET_Stable="${GET_FullVersion:0-27:20}"
		echo $GET_Stable
    else
	    GET_FullVersion=$(cat /tmp/stable_Tags | egrep -o "openwrt-${CURRENT_DEVICE}-stable-[0-9]+.[0-9]+.[0-9]+.[0-9]+.[a-z]+.[a-z]+" | awk 'END {print}')
    	GET_Stable="${GET_FullVersion:0-24:20}"
		echo $GET_Stable
    fi
}

function Nightly(){
    Github_Tags=https://api.github.com/repos/${Author}/releases/latest
    wget -q ${Github_Tags} -O - > /tmp/beta_Tags
    if [[ $CURRENT_DEVICE == x86-64 ]];then
  	    GET_FullVersion=$(cat /tmp/beta_Tags | egrep -o "openwrt-${CURRENT_DEVICE}-beta-[0-9]+.[0-9]+.[0-9]+.[0-9]+.[a-z]+.[a-z]+" | awk 'END {print}')
  	    GET_Nightly="${GET_FullVersion:0-25:18}"
	        echo $GET_Nightly
    else
   	    GET_FullVersion=$(cat /tmp/beta_Tags | egrep -o "openwrt-${CURRENT_DEVICE}-beta-[0-9]+.[0-9]+.[0-9]+.[0-9]+.[a-z]+.[a-z]+" | awk 'END {print}')
   	    GET_Nightly="${GET_FullVersion:0-22:18}"
		echo $GET_Nightly
    fi
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

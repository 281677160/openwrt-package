#!/bin/bash

# Set a fixed value
EMMC_NAME=$(lsblk | grep -oE '(mmcblk[0-9])' | sort | uniq)
FIRMWARE_DOWNLOAD_PATH="/mnt/${EMMC_NAME}p4/.tmp_upload"
TMP_CHECK_DIR="/tmp/amlogic"
AMLOGIC_SOC_FILE="/etc/flippy-openwrt-release"
START_LOG="${TMP_CHECK_DIR}/amlogic_check_firmware.log"
LOG_FILE="${TMP_CHECK_DIR}/amlogic.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
[[ -d ${TMP_CHECK_DIR} ]] || mkdir -p ${TMP_CHECK_DIR}
[[ -d ${FIRMWARE_DOWNLOAD_PATH} ]] || mkdir -p ${FIRMWARE_DOWNLOAD_PATH}

# Log function
tolog() {
    echo -e "${1}" >$START_LOG
    echo -e "${LOGTIME} ${1}" >>$LOG_FILE
    [[ -z "${2}" ]] || exit 1
}

# Current device model
MYDEVICE_NAME=$(cat /proc/device-tree/model 2>/dev/null)
if [[ -z "${MYDEVICE_NAME}" ]]; then
    tolog "The device name is empty and cannot be recognized." "1"
elif [[ "$(echo ${MYDEVICE_NAME} | grep "Chainedbox L1 Pro")" != "" ]]; then
    MYDTB_FILE="rockchip"
    SOC="l1pro"
elif [[ "$(echo ${MYDEVICE_NAME} | grep "BeikeYun")" != "" ]]; then
    MYDTB_FILE="rockchip"
    SOC="beikeyun"
elif [[ "$(echo ${MYDEVICE_NAME} | grep "V-Plus Cloud")" != "" ]]; then
    MYDTB_FILE="allwinner"
    SOC="vplus"
elif [[ -f "${AMLOGIC_SOC_FILE}" ]]; then
    MYDTB_FILE="amlogic"
    source ${AMLOGIC_SOC_FILE} 2>/dev/null
    SOC="${SOC}"
else
    tolog "Unknown device: [ ${MYDEVICE_NAME} ], Not supported." "1"
fi
[[ ! -z "${SOC}" ]] || tolog "The custom firmware soc is invalid." "1"
tolog "Current device: ${MYDEVICE_NAME} [ ${SOC} ]"
sleep 3

# 01. Query local version information
tolog "01. Query version information."
# 01.01 Query the current version
current_kernel_v=$(ls /lib/modules/  2>/dev/null | grep -oE '^[1-9].[0-9]{1,3}.[0-9]+')
tolog "01.01 current version: ${current_kernel_v}"
sleep 3

# 01.01 Version comparison
main_line_ver=$(echo "${current_kernel_v}" | cut -d '.' -f1)
main_line_maj=$(echo "${current_kernel_v}" | cut -d '.' -f2)
main_line_version="${main_line_ver}.${main_line_maj}"

# 01.02. Query the selected branch in the settings
server_kernel_branch=$(uci get amlogic.config.amlogic_kernel_branch 2>/dev/null | grep -oE '^[1-9].[0-9]{1,3}')
if [[ -n "${server_kernel_branch}" && "${server_kernel_branch}" != "${main_line_version}" ]]; then
    main_line_version="${server_kernel_branch}"
    tolog "01.02 Select branch: ${main_line_version}"
    sleep 3
fi

# 01.03. Download server version documentation
server_firmware_url=$(uci get amlogic.config.amlogic_firmware_repo 2>/dev/null)
[[ ! -z "${server_firmware_url}" ]] || tolog "01.03 The custom firmware download repo is invalid." "1"
releases_tag_keywords=$(uci get amlogic.config.amlogic_firmware_tag 2>/dev/null)
[[ ! -z "${releases_tag_keywords}" ]] || tolog "01.04 The custom firmware tag keywords is invalid." "1"
firmware_suffix=$(uci get amlogic.config.amlogic_firmware_suffix 2>/dev/null)
[[ ! -z "${firmware_suffix}" ]] || tolog "01.05 The custom firmware suffix is invalid." "1"

# Supported format:
# server_firmware_url="https://github.com/ophub/amlogic-s9xxx-openwrt"
# server_firmware_url="ophub/amlogic-s9xxx-openwrt"
if [[ ${server_firmware_url} == http* ]]; then
    server_firmware_url=${server_firmware_url#*com\/}
fi

# Delete other residual firmware files
rm -f ${FIRMWARE_DOWNLOAD_PATH}/*${firmware_suffix} 2>/dev/null && sync
rm -f ${FIRMWARE_DOWNLOAD_PATH}/*.img 2>/dev/null && sync
rm -f /mnt/${EMMC_NAME}p4/*${firmware_suffix} 2>/dev/null && sync
rm -f /mnt/${EMMC_NAME}p4/*.img 2>/dev/null && sync

firmware_download_url="https:.*${releases_tag_keywords}.*${SOC}.*${main_line_version}.*${firmware_suffix}"

# 02. Check Updated
check_updated() {
    tolog "02. Start checking the updated ..."

    # Get the openwrt firmware updated_at
    firmware_browser_download_line=$(curl -s "https://api.github.com/repos/${server_firmware_url}/releases" | grep -n "${firmware_download_url}" | awk -F ":" '{print $1}' | head -n 1)
    if [[ -n "${firmware_browser_download_line}" && "${firmware_browser_download_line}" -gt "0" ]]; then
        firmware_updated_line=$(( firmware_browser_download_line - 1 ))
        firmware_releases_updated=$(curl -s "https://api.github.com/repos/${server_firmware_url}/releases" | sed -n "${firmware_updated_line}p" | cut -d '"' -f4 | cut -d 'T' -f1)
        tolog '<input type="button" class="cbi-button cbi-button-reload" value="Download" onclick="return b_check_firmware(this, '"'download'"')"/> Latest updated: '${firmware_releases_updated}''
    else
        tolog "02.02 Invalid firmware check." "1"
    fi

    exit 0
}

# 03. Download Openwrt firmware
download_firmware() {
    tolog "03. Download Openwrt firmware ..."
    # Get the openwrt firmware download path
    firmware_releases_path=$(curl -s "https://api.github.com/repos/${server_firmware_url}/releases" | grep "browser_download_url" | grep -o "${firmware_download_url}" | head -n 1)
    firmware_download_name="openwrt_${SOC}_k${main_line_version}_update${firmware_suffix}"
    wget -c "${firmware_releases_path}" -O "${FIRMWARE_DOWNLOAD_PATH}/${firmware_download_name}" >/dev/null 2>&1 && sync
    if [[ "$?" -eq "0" && -s "${FIRMWARE_DOWNLOAD_PATH}/${firmware_download_name}" ]]; then
        tolog "03.01 OpenWrt firmware download complete, you can update."
    else
        tolog "03.02 Invalid firmware download." "1"
    fi
    sleep 3

    #echo '<a href="javascript:;" onclick="return amlogic_update(this, '"'${firmware_download_name}'"')">Update</a>' >$START_LOG
    tolog '<input type="button" class="cbi-button cbi-button-reload" value="Update" onclick="return amlogic_update(this, '"'${firmware_download_name}'"')"/>'

    exit 0
}

getopts 'cd' opts
case $opts in
    c | check)        check_updated;;
    * | download)     download_firmware;;
esac


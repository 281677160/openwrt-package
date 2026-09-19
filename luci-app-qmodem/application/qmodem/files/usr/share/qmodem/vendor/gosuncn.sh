#!/bin/sh
# Copyright (C) 2025 Fujr <fjrcn@outlook.com>
_Vendor="Gosuncn"
_Author="Fujr"
_Maintainer="Fujr <fjrcn@outlook.com>"
source "${QMODEM_HOME:-/usr/share/qmodem}/generic.sh"
source "${QMODEM_HOME:-/usr/share/qmodem}/cmds/gosuncn.sh"
debug_subject="gosuncn_ctrl"

#获取LTE带宽
# $1:带宽数字
get_lte_bw() {
    local bw_num="$1"
    local bw
    case "$bw_num" in
        "0") bw="1.4" ;;
        "1") bw="3" ;;
        "2"|"3"|"4"|"5") bw="$(((bw_num - 1) * 5))" ;;
        *) bw="" ;;
    esac
    echo "$bw"
}

#将十六进制频段掩码转换为频段号列表
convert2band()
{
    local hex_band="$1"
    local hex=$(echo "$hex_band" | grep -o "[0-9A-Fa-f]\{1,16\}" | tr 'a-f' 'A-F')
    if [ -z "$hex" ]; then
        return
    fi
    local band_list=""
    local bin=$(echo "ibase=16;obase=2;$hex" | bc)
    local len=${#bin}
    local i
    for i in $(seq 1 ${#bin}); do
        if [ "${bin:$((i-1)):1}" = "1" ]; then
            band_list="$band_list $((len - i + 1))"
        fi
    done
    echo "$band_list" | tr ' ' '\n' | sort -n | tr '\n' ' '
}

#将频段号列表转换为十六进制掩码
convert2hex()
{
    local band_list="$1"
    band_list=$(echo "$band_list" | tr ',' '\n' | sort -n | uniq)
    local hex="0"
    local band
    for band in $band_list; do
        local add_hex=$(echo "obase=16;2^($band - 1)" | bc)
        hex=$(echo "obase=16;ibase=16;$hex + $add_hex" | bc)
    done
    if [ -n "$hex" ]; then
        echo "$hex"
    fi
}

get_imei(){
    imei=$(cmd_cgsn "$at_port" | grep -o '[0-9]\{15\}')
    json_add_string imei "$imei"
}

set_imei(){
    local imei="$1"
    cmd_egmr_set_imei "$at_port" "$imei"
}

#获取拨号模式
get_mode()
{
    case "$platform" in
        "qualcomm")
            local mode_raw=$(cmd_zswitch_query "$at_port" | grep -o "+ZSWITCH: [a-zA-Z0-9]" | cut -d' ' -f2)
            case "$mode_raw" in
                "8") mode="mbim" ;;
                "e"|"E") mode="ecm" ;;
                "r"|"R") mode="rndis" ;;
                "x"|"X"|"q"|"Q"|"n"|"N") mode="qmi" ;;
                "p"|"P") mode="eap" ;;
                *) mode="$mode_raw" ;;
            esac
            ;;
        "lte")
            local mode_raw=$(cmd_zswitch_query "$at_port" | grep -o "+ZSWITCH: [a-zA-Z]" | cut -d' ' -f2)
            case "$mode_raw" in
                "e") mode="mbim" ;;
                "x") mode="qmi" ;;
                "r") mode="rndis" ;;
                "l") mode="ecm" ;;
                *) mode="$mode_raw" ;;
            esac
            ;;
        *)
            local mode_raw=$(cmd_zswitch_query "$at_port" | grep -o "+ZSWITCH: [a-zA-Z]" | cut -d' ' -f2)
            case "$mode_raw" in
                "e") mode="mbim" ;;
                "x") mode="qmi" ;;
                "r") mode="rndis" ;;
                "E") mode="ecm" ;;
                *) mode="$mode_raw" ;;
            esac
            ;;
    esac

    available_modes=$(uci -q get qmodem.$config_section.modes)
    json_add_object "mode"
    for available_mode in $available_modes; do
        if [ "$mode" = "$available_mode" ]; then
            json_add_string "$available_mode" "1"
        else
            json_add_string "$available_mode" "0"
        fi
    done
    json_close_object
}

#设置拨号模式
set_mode()
{
    local mode=$1
    case "$platform" in
        "qualcomm")
            case "$mode" in
                "mbim")
                    cmd_zswitch_set "$at_port" "8"
                    ;;
                "qmi")
                    cmd_zswitch_set "$at_port" "x"
                    ;;
                "rndis")
                    cmd_zswitch_set "$at_port" "r"
                    ;;
                "ecm")
                    cmd_zswitch_set "$at_port" "e"
                    ;;
                *)
                    echo "Invalid mode"
                    return 1
                    ;;
            esac
            ;;
        "lte")
            case $mode in
                "mbim")
                    cmd_zswitch_set "$at_port" "e"
                    ;;
                "qmi")
                    cmd_zswitch_set "$at_port" "x"
                    ;;
                "rndis")
                    cmd_zswitch_set "$at_port" "r"
                    ;;
                "ecm")
                    cmd_zswitch_set "$at_port" "l"
                    ;;
                *)
                    echo "Invalid mode"
                    return 1
                    ;;
            esac
            ;;
        *)
            case $mode in
                "mbim")
                    cmd_zswitch_set "$at_port" "e"
                    ;;
                "qmi")
                    cmd_zswitch_set "$at_port" "x"
                    ;;
                "rndis")
                    cmd_zswitch_set "$at_port" "r"
                    ;;
                "ecm")
                    cmd_zswitch_set "$at_port" "E"
                    ;;
                *)
                    echo "Invalid mode"
                    return 1
                    ;;
            esac
            ;;
    esac
}

#获取网络偏好
get_network_prefer()
{
    case "$platform" in
        "qualcomm")
            get_network_prefer_qualcomm
            ;;
        "lte")
            get_network_prefer_lte
            ;;
        *)
            get_network_prefer_lte
            ;;
    esac
}

get_network_prefer_lte()
{
    # AT+ZSNT? 返回格式: +ZSNT: cm_mode,net_sel_mode,pref_acq
    # cm_mode: 0=自动, 2=WCDMA, 6=LTE
    local res=$(cmd_zsnt_query "$at_port" | grep -o "+ZSNT: [0-9,]*" | cut -d' ' -f2)
    local cm_mode=$(echo "$res" | cut -d',' -f1)

    network_prefer_3g="0"
    network_prefer_4g="0"

    case "$cm_mode" in
        "0")
            network_prefer_3g="1"
            network_prefer_4g="1"
            ;;
        "2")
            network_prefer_3g="1"
            ;;
        "6")
            network_prefer_4g="1"
            ;;
    esac

    json_add_object network_prefer
    json_add_string 3G "$network_prefer_3g"
    json_add_string 4G "$network_prefer_4g"
    json_close_object
}

get_network_prefer_qualcomm()
{
    local res=$(cmd_zsnt_query "$at_port" | grep -o "+ZSNT: [0-9,]*" | cut -d' ' -f2)
    local cm_mode=$(echo "$res" | cut -d',' -f1)

    network_prefer_3g="0"
    network_prefer_4g="0"
    network_prefer_5g="0"

    # 0=AUTOMATIC, 2=WCDMA_ONLY, 6=LTE_ONLY, 7=NR5G_ONLY, 8=LTE NR.
    case "$cm_mode" in
        "0")
            network_prefer_3g="1"
            network_prefer_4g="1"
            network_prefer_5g="1"
            ;;
        "2")
            network_prefer_3g="1"
            ;;
        "6")
            network_prefer_4g="1"
            ;;
        "7")
            network_prefer_5g="1"
            ;;
        "8")
            network_prefer_4g="1"
            network_prefer_5g="1"
            ;;
    esac

    json_add_object network_prefer
    json_add_string 3G "$network_prefer_3g"
    json_add_string 4G "$network_prefer_4g"
    json_add_string 5G "$network_prefer_5g"
    json_close_object
}

#设置网络偏好
set_network_prefer()
{
    local config="$1"
    network_prefer_3g=$(echo "$config" | jq -r 'contains(["3G"])')
    network_prefer_4g=$(echo "$config" | jq -r 'contains(["4G"])')
    network_prefer_5g=$(echo "$config" | jq -r 'contains(["5G"])')
    local length=$(echo "$config" | jq -r 'length')
    local zsnt_mode="0,0,0"

    case "$platform" in
        "qualcomm")
            set_network_prefer_qualcomm "$length"
            ;;
        "lte")
            set_network_prefer_lte "$length"
            ;;
        *)
            set_network_prefer_lte "$length"
            ;;
    esac
}

set_network_prefer_lte()
{
    local length="$1"
    local zsnt_mode

    case "$length" in
        "1")
            if [ "$network_prefer_3g" = "true" ]; then
                zsnt_mode="2,0,0"
            elif [ "$network_prefer_4g" = "true" ]; then
                zsnt_mode="6,0,0"
            fi
            ;;
        "2")
            zsnt_mode="0,0,0"
            ;;
        *)
            zsnt_mode="0,0,0"
            ;;
    esac

    cmd_zsnt_set "$at_port" "$zsnt_mode"
}

set_network_prefer_qualcomm()
{
    local length="$1"
    local zsnt_mode

    case "$length" in
        "1")
            if [ "$network_prefer_3g" = "true" ]; then
                zsnt_mode="2,0,0"
            elif [ "$network_prefer_4g" = "true" ]; then
                zsnt_mode="6,0,0"
            elif [ "$network_prefer_5g" = "true" ]; then
                zsnt_mode="7,0,0"
            fi
            ;;
        "2")
            if [ "$network_prefer_4g" = "true" ] && [ "$network_prefer_5g" = "true" ]; then
                zsnt_mode="8,0,0"
            else
                zsnt_mode="0,0,0"
            fi
            ;;
        *)
            zsnt_mode="0,0,0"
            ;;
    esac

    cmd_zsnt_set "$at_port" "$zsnt_mode"
}

#获取温度
get_temperature()
{
    local temp=$(cmd_mtsm "$at_port" | grep '+MTSM:' | cut -d: -f2 | tr -d ' \r')
    if [ -n "$temp" ]; then
        temp="${temp}$(printf "\xc2\xb0")C"
    fi
    add_plain_info_entry "temperature" "$temp" "Temperature"
}

#获取锁频信息
get_lockband()
{
    json_add_object "lockband"
    case "$platform" in
        "qualcomm")
            get_lockband_qualcomm
            ;;
        "lte")
            get_lockband_lte
            ;;
        *)
            get_lockband_lte
            ;;
    esac
    json_close_object
}

get_lockband_lte()
{
    m_debug "Gosuncn LTE get lockband info"
    # AT+ZBAND? 返回当前锁定的LTE频段
    # AT+ZBAND=? 返回支持的LTE频段
    local modem_info=$(cmd_zband_query "$at_port" | grep -i 'LTE' | cut -d: -f2 | tr -d '\r ')
    local LTE_LOCK_SUPPORTBAND=$(cmd_zband_list_query "$at_port" | grep -i 'LTE' | cut -d: -f2 | tr -d '() \r')

    local lte_available_band=""
    [ -n "$(uci -q get qmodem.$config_section.lte_band)" ] && lte_available_band=$(uci -q get qmodem.$config_section.lte_band | tr '/' ',')

    json_add_object "LTE"
    json_add_array "available_band"
    if [ -n "$lte_available_band" ]; then
        for band in $(echo "$lte_available_band" | tr ',' '\n' | sort -n | uniq); do
            add_avalible_band_entry "$band" "LTE_B$band"
        done
    elif [ -n "$LTE_LOCK_SUPPORTBAND" ]; then
        for band in $(echo "$LTE_LOCK_SUPPORTBAND" | tr ',' '\n' | sort -n | uniq); do
            add_avalible_band_entry "$band" "LTE_B$band"
        done
    fi
    json_close_array

    json_add_array "lock_band"
    if [ -n "$modem_info" ]; then
        for band in $(echo "$modem_info" | tr ',' '\n' | sort -n | uniq); do
            json_add_string "" "$band"
        done
    fi
    json_close_array
    json_close_object
}

get_lockband_qualcomm()
{
    m_debug "Gosuncn qualcomm get lockband info"
    local wcdma_available="1,2,3,4,5,8"
    local lte_available="1,2,3,4,5,7,8,12,13,14,17,18,19,20,25,26,28,29,30,38,39,40,41,42,43,48,66,71"
    local nr_available="1,2,3,5,7,8,20,28,41,66,71,77,78,79"

    local zband_response=$(cmd_zband_query "$at_port" | tr -d ' \r')
    local wcdma_modem=$(echo "$zband_response" | grep -i 'WCDMA' | cut -d':' -f2)
    local lte_modem=$(echo "$zband_response" | grep -i 'LTE' | cut -d':' -f2)
    local nr_modem=$(echo "$zband_response" | grep -i 'NR5G' | cut -d':' -f2)

    [ -n "$(uci -q get qmodem.$config_section.wcdma_band)" ] && \
        wcdma_available=$(uci -q get qmodem.$config_section.wcdma_band | tr '/' ',')
    [ -n "$(uci -q get qmodem.$config_section.lte_band)" ] && \
        lte_available=$(uci -q get qmodem.$config_section.lte_band | tr '/' ',')
    [ -n "$(uci -q get qmodem.$config_section.sa_band)" ] && \
        nr_available=$(uci -q get qmodem.$config_section.sa_band | tr '/' ',')

    json_add_object "WCDMA"
    json_add_array "available_band"
    for band in $(echo "$wcdma_available" | tr ',' '\n' | sort -n | uniq); do
        [ -n "$band" ] && add_avalible_band_entry "$band" "WCDMA_B_$band"
    done
    json_close_array
    json_add_array "lock_band"
    for band in $(echo "$wcdma_modem" | tr ',' '\n' | sort -n | uniq); do
        [ -n "$band" ] && json_add_string "" "$band"
    done
    json_close_array
    json_close_object

    json_add_object "LTE"
    json_add_array "available_band"
    for band in $(echo "$lte_available" | tr ',' '\n' | sort -n | uniq); do
        [ -n "$band" ] && add_avalible_band_entry "$band" "LTE_B$band"
    done
    json_close_array
    json_add_array "lock_band"
    for band in $(echo "$lte_modem" | tr ',' '\n' | sort -n | uniq); do
        [ -n "$band" ] && json_add_string "" "$band"
    done
    json_close_array
    json_close_object

    json_add_object "NR"
    json_add_array "available_band"
    for band in $(echo "$nr_available" | tr ',' '\n' | sort -n | uniq); do
        [ -n "$band" ] && add_avalible_band_entry "$band" "NR_N$band"
    done
    json_close_array
    json_add_array "lock_band"
    for band in $(echo "$nr_modem" | tr ',' '\n' | sort -n | uniq); do
        [ -n "$band" ] && json_add_string "" "$band"
    done
    json_close_array
    json_close_object
}

#设置锁频
set_lockband()
{
    m_debug "Gosuncn set lockband info"
    local config="$1"
    local band_class=$(echo "$config" | jq -r '.band_class')
    local lock_band=$(echo "$config" | jq -r '.lock_band')

    case "$platform" in
        "qualcomm")
            set_lockband_qualcomm "$band_class" "$lock_band"
            ;;
        "lte")
            set_lockband_lte "$band_class" "$lock_band"
            ;;
        *)
            set_lockband_lte "$band_class" "$lock_band"
            ;;
    esac

    json_select "result"
    json_add_string "set_lockband" "$res"
    json_add_string "config" "$config"
    json_add_string "band_class" "$band_class"
    json_add_string "lock_band" "$lock_band"
    json_close_object
}

set_lockband_lte()
{
    local band_class="$1"
    local lock_band="$2"

    if [ -z "$lock_band" ] || [ "$lock_band" = "null" ]; then
        # 解锁所有频段
        res=$(cmd_zband_reset_all_lte "$at_port")
    else
        local hex=$(convert2hex "$lock_band")
        m_debug "Lock LTE band hex: $hex"
        res=$(cmd_zband_set_lte "$at_port" "$hex")
    fi
}

set_lockband_qualcomm()
{
    local band_class="$1"
    local lock_band="$2"

    if [ -z "$lock_band" ] || [ "$lock_band" = "null" ]; then
        res=$(cmd_zband_reset_all_qualcomm "$at_port")
        return
    fi

    case "$lock_band" in
        *[!0-9,]*)
            res="ERROR: invalid band list"
            return
            ;;
    esac

    local band_list=$(echo "$lock_band" | tr ',' '\n' | grep -v '^$' | sort -n | uniq)

    if [ -z "$band_list" ]; then
        res="ERROR: invalid band list"
        return
    fi

    local band_count=$(echo "$band_list" | wc -l)

    if [ "$band_count" -lt 1 ] || [ "$band_count" -gt 10 ]; then
        res="ERROR: ZBAND supports 1-10 bands per command"
        return
    fi

    for band in $band_list; do
        if [ "$band" -lt 1 ] || [ "$band" -gt 320 ]; then
            res="ERROR: band must be in range 1-320"
            return
        fi
    done

    local clean_lock_band=$(echo "$band_list" | tr '\n' ',')
    clean_lock_band="${clean_lock_band%,}"
    case "$band_class" in
        "WCDMA")
            res=$(cmd_zband_set_qualcomm "$at_port" "3" "$band_count" "$clean_lock_band")
            ;;
        "LTE")
            res=$(cmd_zband_set_qualcomm "$at_port" "1" "$band_count" "$clean_lock_band")
            ;;
        "NR")
            res=$(cmd_zband_set_qualcomm "$at_port" "5" "$band_count" "$clean_lock_band")
            ;;
        *)
            res="ERROR: unsupported band_class: $band_class"
            ;;
    esac
}

#SIM卡信息
sim_info()
{
    m_debug "Gosuncn sim info"
    class="SIM Information"

    #IMEI
    imei=$(cmd_cgsn "$at_port" | grep -o "[0-9]\{15\}")

    #SIM Status
    sim_status_flag=$(cmd_cpin_query "$at_port" | sed -n '2p')
    sim_status=$(get_sim_status "$sim_status_flag")

    if [ "$sim_status" != "ready" ]; then
        add_plain_info_entry "SIM Status" "$sim_status" "SIM Status"
        add_plain_info_entry "IMEI" "$imei" "International Mobile Equipment Identity"
        return
    fi

    #ISP
    cmd_cops_numeric "$at_port" > /dev/null 2>&1
    isp=$(cmd_cops_query "$at_port" | sed -n '2p' | awk -F'"' '{print $2}')

    #SIM Number
    sim_number=$(cmd_cnum "$at_port" | grep "+CNUM:" | grep -o "[0-9]\{9,\}")

    #IMSI
    imsi=$(cmd_cimi "$at_port" | sed -n '2p' | sed 's/\r//g')

    #ICCID
    iccid=$(cmd_iccid "$at_port" | grep -o "+\?ICCID:[ ]*[-0-9A-Fa-f]\+" | awk -F': ' '{print $2}' | tr -d ' ')

    add_plain_info_entry "SIM Status" "$sim_status" "SIM Status"
    add_plain_info_entry "ISP" "$isp" "Internet Service Provider"
    add_plain_info_entry "SIM Slot" "$sim_slot" "SIM Slot"
    add_plain_info_entry "SIM Number" "$sim_number" "SIM Number"
    add_plain_info_entry "IMEI" "$imei" "International Mobile Equipment Identity"
    add_plain_info_entry "IMSI" "$imsi" "International Mobile Subscriber Identity"
    add_plain_info_entry "ICCID" "$iccid" "Integrate Circuit Card Identity"
}

#基本信息
base_info()
{
    m_debug "Gosuncn base info"
    class="Base Information"

    #Name
    name=$(cmd_cgmm "$at_port" | sed -n '2p' | sed 's/\r//g')

    #Manufacturer
    manufacturer=$(cmd_cgmi "$at_port" | sed -n '2p' | sed 's/\r//g')

    #Revision
    revision=$(cmd_cgmr "$at_port" | sed -n '2p' | sed 's/\r//g')

    add_plain_info_entry "name" "$name" "Name"
    add_plain_info_entry "manufacturer" "$manufacturer" "Manufacturer"
    add_plain_info_entry "revision" "$revision" "Revision"
    add_plain_info_entry "at_port" "$at_port" "AT Port"
    get_temperature
    get_connect_status
}

#网络信息
network_info()
{
    m_debug "Gosuncn network info"

    #Network Type（网络类型）
    local cops_response=$(cmd_cops_query "$at_port" | grep "+COPS:")
    local carrier=$(echo "$cops_response" | awk -F'"' '{print $2}')
    local rat_num=$(echo "$cops_response" | awk -F',' '{print $4}' | sed 's/\r//g')
    local network_type=$(get_rat $rat_num)

    #CSQ
    response=$(cmd_csq "$at_port" | grep "+CSQ:" | sed 's/+CSQ: //g' | sed 's/\r//g')

    class="Network Information"
    add_plain_info_entry "Network Type" "$network_type" "Network Type"
    add_plain_info_entry "Carrier" "$carrier" "Carrier"
}

#小区信息
cell_info()
{
    m_debug "Gosuncn cell info"

    case "$platform" in
        "qualcomm")
            cell_info_qualcomm
            ;;
        "lte")
            cell_info_lte
            ;;
        *)
            cell_info_lte
            ;;
    esac
}

cell_info_lte()
{
    # AT+ZCELLINFO? 返回 +ZCELLINFO: <TAC>,cellid:<CellID>,pci:<PCI>,band:<Band>
    local zcellinfo=$(cmd_zcellinfo_query "$at_port" | grep '+ZCELLINFO:' | cut -d: -f2-)
    local cops_response=$(cmd_cops_query "$at_port" | grep "+COPS:")
    local rat_num=$(echo "$cops_response" | awk -F',' '{print $4}' | sed 's/\r//g')
    local network_type=$(get_rat $rat_num)

    if [ -z "$zcellinfo" ]; then
        return
    fi

    # 解析 ZCELLINFO 字段
    local tac=$(echo "$zcellinfo" | cut -d',' -f1 | tr -d ' ')
    local cell_id=$(echo "$zcellinfo" | cut -d',' -f2 | tr -d ' ')
    local pci=$(echo "$zcellinfo" | cut -d',' -f3 | tr -d ' ')
    local band=$(echo "$zcellinfo" | cut -d',' -f4 | tr -d '\r' | tr -d '\n')

    # 获取信号质量
    local cesq_response=$(cmd_cesq "$at_port" | grep "+CESQ:")
    local rsrp="" rsrq="" sinr=""
    if [ -n "$cesq_response" ]; then
        # +CESQ: rxlev,ber,rscp,ecno,rsrq,rsrp
        rsrq=$(echo "$cesq_response" | awk -F',' '{print $5}' | tr -d ' ')
        rsrp=$(echo "$cesq_response" | awk -F',' '{print $6}' | tr -d ' \r')
        # 转换 RSRP: 实际值 = 报告值 - 141
        if [ -n "$rsrp" ] && [ "$rsrp" != "255" ]; then
            rsrp=$(($rsrp - 141))
        else
            rsrp=""
        fi
        # 转换 RSRQ: 实际值 = (报告值 / 2) - 19.5
        if [ -n "$rsrq" ] && [ "$rsrq" != "255" ]; then
            rsrq=$(echo "$rsrq" | awk '{printf "%.1f", ($1 / 2) - 19.5}')
        else
            rsrq=""
        fi
    fi

    # 获取 RSSI/SINR（通过CSQ）
    local csq_response=$(cmd_csq "$at_port" | grep "+CSQ:")
    local rssi=""
    if [ -n "$csq_response" ]; then
        local csq_num=$(echo "$csq_response" | awk -F'[:,]' '{print $2}' | tr -d ' ')
        if [ "$csq_num" != "99" ] && [ -n "$csq_num" ]; then
            rssi="$((2 * csq_num - 113))"
        fi
    fi

    # 获取MCC/MNC
    cmd_cops_numeric "$at_port" > /dev/null 2>&1
    local cops_num=$(cmd_cops_query "$at_port" | grep "+COPS:" | awk -F'"' '{print $2}')
    local mcc="" mnc=""
    if [ -n "$cops_num" ] && [ ${#cops_num} -ge 5 ]; then
        mcc=${cops_num:0:3}
        mnc=${cops_num:3}
    fi

    class="Cell Information"
    case "$network_type" in
        "LTE")
            network_mode="LTE Mode"
            add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
            set_4g_cell_info "$mcc" "$mnc" "$tac" "$cell_id" "" "$pci" "$band" "" "" "$rsrp" "$rsrq" "" "" ""
            add_bar_info_entry "RSSI" "$rssi" "Received Signal Strength Indicator" -120 -20 dBm
            ;;
        "WCDMA")
            network_mode="WCDMA Mode"
            add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
            add_plain_info_entry "LAC" "$tac" "Location Area Code"
            add_plain_info_entry "Cell ID" "$cell_id" "Cell ID"
            add_plain_info_entry "PSC" "$pci" "Primary Scrambling Code"
            add_plain_info_entry "Band" "$band" "Band"
            add_bar_info_entry "RSSI" "$rssi" "Received Signal Strength Indicator" -120 -20 dBm
            ;;
        *)
            network_mode="${network_type} Mode"
            add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
            add_plain_info_entry "TAC" "$tac" "Tracking Area Code"
            add_plain_info_entry "Cell ID" "$cell_id" "Cell ID"
            add_plain_info_entry "PCI" "$pci" "Physical Cell ID"
            add_plain_info_entry "Band" "$band" "Band"
            add_bar_info_entry "RSSI" "$rssi" "Received Signal Strength Indicator" -120 -20 dBm
            ;;
    esac
}

cell_info_qualcomm()
{
    local cell=$(cmd_zcellinfo_query "$at_port" | tr -d ' \r')
    local zcellinfo=$(echo "$cell" | grep '+ZCELLINFO:')
    local zcellinfo_nsa=$(echo "$cell" | grep 'narfcn:')

    if [ -z "$zcellinfo" ]; then
        return
    fi

    local network_type=$(echo "$zcellinfo" | awk -F':' '{print $2}')
    local tac=$(echo "$zcellinfo" | grep -o 'tac:[^,]*' | cut -d':' -f2)
    local lac=$(echo "$zcellinfo" | grep -o 'lac:[^,]*' | cut -d':' -f2)
    local cell_id=$(echo "$zcellinfo" | grep -o 'cell_\?id:[^,]*' | cut -d':' -f2)
    local pci=$(echo "$zcellinfo" | grep -o 'pci:[^,]*' | cut -d':' -f2)
    local psc=$(echo "$zcellinfo" | grep -o 'psc:[^,]*' | cut -d':' -f2)
    local band=$(echo "$zcellinfo" | grep -o 'band:[^,]*' | cut -d':' -f2)
    local freq=$(echo "$zcellinfo" | grep -o 'freq:[^,]*' | cut -d':' -f2)
    local mcc=$(echo "$zcellinfo" | grep -o 'mcc:[^,]*' | cut -d':' -f2)
    local mnc=$(echo "$zcellinfo" | grep -o 'mnc:[^,]*' | cut -d':' -f2)
    local rsrp=$(echo "$zcellinfo" | grep -o 'rsrp:[^,]*' | cut -d':' -f2)
    local rsrq=$(echo "$zcellinfo" | grep -o 'rsrq:[^,]*' | cut -d':' -f2)
    local rssi=$(echo "$zcellinfo" | grep -o 'rssi:[^,]*' | cut -d':' -f2)
    local sinr=$(echo "$zcellinfo" | grep -o 'sinr:[^,]*' | cut -d':' -f2)
    local rscp=$(echo "$zcellinfo" | grep -o 'rscp:[^,]*' | cut -d':' -f2)
    local ecio=$(echo "$zcellinfo" | grep -o 'ecio:[^,]*' | cut -d':' -f2)

    class="Cell Information"
    case "$network_type" in
        "NR5G")
            network_mode="NR5G-SA Mode"
            add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
            set_5g_cell_info "$mcc" "$mnc" "$tac" "$cell_id" "$freq" "$pci" "$band" "" "" "$rsrp" "$rsrq" "$sinr" "" ""
            ;;
        "LTE")
            if [ -n "$zcellinfo_nsa" ]; then
                local nsa_freq=$(echo "$zcellinfo_nsa" | grep -o 'narfcn:[^,]*' | cut -d':' -f2)
                local nsa_pci=$(echo "$zcellinfo_nsa" | grep -o 'nr5g_pci:[^,]*' | cut -d':' -f2)
                local nsa_cell_id=$(echo "$zcellinfo_nsa" | grep -o 'cell_id:[^,]*' | cut -d':' -f2)
                local nsa_band=$(echo "$zcellinfo_nsa" | grep -o 'band:[^,]*' | cut -d':' -f2)
                local nsa_rsrp=$(echo "$zcellinfo_nsa" | grep -o '5g_rsrp:[^,]*' | cut -d':' -f2)
                local nsa_rsrq=$(echo "$zcellinfo_nsa" | grep -o '5g_rsrq:[^,]*' | cut -d':' -f2)
                local nsa_sinr=$(echo "$zcellinfo_nsa" | grep -o '5g_sinr:[^,]*' | cut -d':' -f2)

                network_mode="EN-DC Mode"
                add_plain_info_entry "network_mode" "$network_mode" "Network Mode"

                add_plain_info_entry "LTE" "LTE" ""
                extra_info="LTE"
                set_4g_cell_info "$mcc" "$mnc" "$tac" "$cell_id" "$freq" "$pci" "$band" "" "" "$rsrp" "$rsrq" "$sinr" "" ""
                add_bar_info_entry "RSSI" "$rssi" "Received Signal Strength Indicator" -120 -20 dBm

                add_plain_info_entry "NR5G-NSA" "NR5G-NSA" ""
                extra_info="NR"
                set_5g_cell_info "" "" "" "$nsa_cell_id" "$nsa_freq" "$nsa_pci" "$nsa_band" "" "" "$nsa_rsrp" "$nsa_rsrq" "$nsa_sinr" "" ""
            else
                network_mode="LTE Mode"
                add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
                set_4g_cell_info "$mcc" "$mnc" "$tac" "$cell_id" "$freq" "$pci" "$band" "" "" "$rsrp" "$rsrq" "$sinr" "" ""
                add_bar_info_entry "RSSI" "$rssi" "Received Signal Strength Indicator" -120 -20 dBm
            fi
            ;;
        "lac")
            if [ -n "$freq" ]; then
                network_mode="WCDMA Mode"
                add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
                set_3g_cell_info "$mcc" "$mnc" "$lac" "$cell_id" "$freq" "$psc" "$band" "" "" "$rscp" "" "$ecio" "" ""
            else
                if [ -n "$ecio" ]; then
                    network_mode="GSM Mode"
                    add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
                    set_3g_cell_info "$mcc" "$mnc" "$lac" "$cell_id" "" "" "$band" "" "" "" "" "$ecio" "" ""
                else
                    network_mode="TDSCDMA"
                    add_plain_info_entry "network_mode" "$network_mode" "Network Mode"
                    set_3g_cell_info "" "" "$lac" "$cell_id" "" "" "$band" "" "" "" "" "" "" ""
                fi
            fi
            ;;
        *)
            return
            ;;
    esac
}

#邻区信息
get_neighborcell()
{
    #not real responses
    #examples for set_neighborcell() paras quick copy
    json_add_object "neighborcell"
    json_add_array "LTE"
    json_add_object ""
    json_add_string "neighbourcell" "ex1"
    json_add_string "arfcn" "1850"
    json_add_string "pci" "317"
    json_add_string "band" "3"
    json_add_string "rssi" "-57.00"
    json_add_string "rsrp" "-88.40"
    json_add_string "rsrq" "-9.90"
    json_add_string "sinr" "4"
    json_close_object
    json_close_array

    json_add_array "NR"
    json_add_object ""
    json_add_string "neighbourcell" "ex2"
    json_add_string "arfcn" "504990"
    json_add_string "pci" "241"
    json_add_string "scs" "0"
    json_add_string "band" "41"
    json_add_string "rsrp" "-87"
    json_add_string "rsrq" "-11"
    json_add_string "sinr" "17"
    json_close_object

    json_add_object ""
    json_add_string "neighbourcell" "ex3"
    json_add_string "arfcn" "633984"
    json_add_string "pci" "397"
    json_add_string "scs" "1"
    json_add_string "band" "78"
    json_add_string "rsrp" "-89"
    json_add_string "rsrq" "-12"
    json_add_string "sinr" "14"
    json_close_object
    json_close_array

    local zlockcell=$(cmd_zlockcell_query "$at_port" | tr -d ' \r')
    local lte_status=$(echo "$zlockcell" | grep -i "lte")
    local nr_status=$(echo "$zlockcell" | grep -i "nr5g")
    local lte_lock_status=$(echo "$lte_status" | awk -F':' '{print $NF}')
    local nr_lock_status=$(echo "$nr_status" | awk -F':' '{print $NF}')

    if [ "$lte_lock_status" == "on" ]; then
        lte_lock_status="locked"
        local lte_lock_freq=$(echo "$lte_status" | grep -o "earfcn:[^,]*" | cut -d':' -f2)
        local lte_lock_pci=$(echo "$lte_status" | grep -o "pci:[^,]*" | cut -d':' -f2)
    else
        lte_lock_status=""
    fi

    if [ "$nr_lock_status" == "on" ]; then
        nr_lock_status="locked"
        local nr_lock_pci=$(echo "$nr_status" | grep -o "pci:[^,]*" | cut -d':' -f2)
        local nr_lock_freq=$(echo "$nr_status" | grep -o "nr5g_chanel:[^,]*" | cut -d':' -f2)
        local nr_lock_scs=$(echo "$nr_status" | grep -o "scs:[^,]*" | cut -d':' -f2)
        local nr_lock_band=$(echo "$nr_status" | grep -o "band:[^,]*" | cut -d':' -f2)
    else
        nr_lock_status=""
    fi

    json_add_object "lockcell_status"
    if [ -n "$lte_lock_status" ]; then
        json_add_string "LTE" "$lte_lock_status"
        json_add_string "LTE_Freq" "$lte_lock_freq"
        json_add_string "LTE_PCI" "$lte_lock_pci"
    else
        json_add_string "LTE" "unlock"
    fi
    if [ -n "$nr_lock_status" ]; then
        json_add_string "NR" "$nr_lock_status"
        json_add_string "NR_Freq" "$nr_lock_freq"
        json_add_string "NR_PCI" "$nr_lock_pci"
        json_add_string "NR_SCS" "$nr_lock_scs"
        json_add_string "NR_Band" "$nr_lock_band"
    else
        json_add_string "NR" "unlock"
    fi
    json_close_object

    qmodem_lockcell_boot_hook_add_json "$config_section"
    json_close_object
}

set_neighborcell()
{
    local json_param=$1
    local rat=$(echo "$json_param" | jq -r '.rat')
    local pci=$(echo "$json_param" | jq -r '.pci')
    local arfcn=$(echo "$json_param" | jq -r '.arfcn')
    local band=$(echo "$json_param" | jq -r '.band')
    local scs=$(echo "$json_param" | jq -r '.scs')
    local en_boot_hook=$(echo $json_param | jq -r '.en_boot_hook // empty')

    if [ -z "$pci" ] || [ -z "$arfcn" ]; then
        #unlock
        res=$(cmd_zlockcell_unlock "$at_port")
        qmodem_lockcell_boot_hook_clear "$config_section"
    else
        if [ "$rat" == "1" ]; then
            #nr
            lockcell_boot_cmd="AT+ZLOCKCELL=1,2,$arfcn,$pci,$scs,$band"
            res=$(cmd_zlockcell_set_nr "$at_port" "$arfcn" "$pci" "$scs" "$band")
        else
            #lte
            lockcell_boot_cmd="AT+ZLOCKCELL=1,1,$arfcn,$pci"
            res=$(cmd_zlockcell_set_lte "$at_port" "$arfcn" "$pci")
        fi
        qmodem_lockcell_boot_hook_sync "$config_section" "$en_boot_hook" "$lockcell_boot_cmd"
    fi

    json_select "result"
    json_add_string "setlockcell" "$res"
    json_add_string "rat" "$rat"
    json_add_string "pci" "$pci"
    json_add_string "arfcn" "$arfcn"
    json_add_string "band" "$band"
    json_add_string "scs" "$scs"
    if qmodem_bool_enabled "$(uci -q get "qmodem.${config_section}.lockcell_boot_hook_enabled")"; then
        json_add_boolean "boot_hook_enabled" 1
    else
        json_add_boolean "boot_hook_enabled" 0
    fi
    json_close_object
}

vendor_get_disabled_features()
{
    if [ "$platform" == "lte" ]; then
        json_add_string "" "NeighborCell"
    fi
}

#重启模组
soft_reboot()
{
    cmd_cfun_soft_reboot "$at_port"
}

#重置模组
reset_module()
{
    cmd_zsnt_reset "$at_port" > /dev/null 2>&1
    case "$platform" in
        "qualcomm")
            cmd_zband_reset_all_qualcomm "$at_port" > /dev/null 2>&1
            ;;
        "lte")
            cmd_zband_reset_all_lte "$at_port" > /dev/null 2>&1
            ;;
        *)
            cmd_zband_reset_all_lte "$at_port" > /dev/null 2>&1
            ;;
    esac
    cmd_atf_factory "$at_port" > /dev/null 2>&1
}

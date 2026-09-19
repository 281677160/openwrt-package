#!/bin/sh
# Gosuncn AT command wrappers.
# Vendor scripts must send AT commands only through these cmd_* interfaces.
# Convention: $1 is the AT port, remaining args are command parameters.

#query IMEI
cmd_cgsn()
{
    at "$1" "AT+CGSN"
}

#set IMEI
#$2: imei
cmd_egmr_set_imei()
{
    at "$1" "AT+EGMR=1,7,\"$2\""
}

#query network mode
cmd_zswitch_query()
{
    at "$1" "AT+ZSWITCH?"
}

#set usb network mode
#$2: mode (8=MBIM, e/E=ECM, r/R=RNDIS, x/X or q/Q=QMI)
cmd_zswitch_set()
{
    at "$1" "AT+ZSWITCH=$2"
}

#query network selection
cmd_zsnt_query()
{
    at "$1" "AT+ZSNT?"
}

#set network selection
#$2: zsnt mode
cmd_zsnt_set()
{
    at "$1" "AT+ZSNT=$2"
}

#reset network selection
cmd_zsnt_reset()
{
    at "$1" "AT+ZSNT=0,0,0"
}

#query current network access state
cmd_zpas_query()
{
    at "$1" "AT+ZPAS?"
}

#query 5G registration state
cmd_c5greg_query()
{
    at "$1" "AT+C5GREG?"
}

#query temperature
cmd_mtsm()
{
    at "$1" "AT+MTSM=1"
}

#query current band config
cmd_zband_query()
{
    at "$1" 'AT+ZBAND?'
}

#query supported bands
cmd_zband_list_query_lte()
{
    at "$1" 'AT+ZBAND=?'
}

#reset bands to all
cmd_zband_reset_all_lte()
{
    at "$1" "AT+ZBAND=all,all,all,all"
}

cmd_zband_reset_all_qualcomm()
{
    at "$1" "AT+ZBAND=0"
}

#lock bands
#$2: hex band mask
cmd_zband_set_lte()
{
    at "$1" "AT+ZBAND=all,all,all,$2"
}

#$2: RAT (0=Unlock, 1=LTE, 2=TDSCDMA, 3=WCDMA, 4=GSM, 5=NR5G)
#$3: number of bands (1-10)
#$4: comma-separated band list
cmd_zband_set_qualcomm()
{
    at "$1" "AT+ZBAND=$2,$3,$4"
}


#query cell-lock state
cmd_zlockcell_query()
{
    at "$1" "AT+ZLOCKCELL?"
}

#set LTE cell lock
#$2: earfcn  $3: pci
cmd_zlockcell_set_lte()
{
    at "$1" "AT+ZLOCKCELL=1,1,$2,$3"
}

#set NR5G cell lock
#$2: narfcn  $3: pci  $4: scs(0-3)  $5: nr band
cmd_zlockcell_set_nr()
{
    at "$1" "AT+ZLOCKCELL=1,2,$2,$3,$4,$5"
}

#unlock all cell locks
cmd_zlockcell_unlock()
{
    at "$1" "AT+ZLOCKCELL=0"
}

#query SIM status
cmd_cpin_query()
{
    at "$1" "AT+CPIN?"
}

#set COPS numeric format
cmd_cops_numeric()
{
    at "$1" "AT+COPS=3,2"
}

#query operator selection
cmd_cops_query()
{
    at "$1" "AT+COPS?"
}

#query subscriber number
cmd_cnum()
{
    at "$1" "AT+CNUM"
}

#query IMSI
cmd_cimi()
{
    at "$1" "AT+CIMI"
}

#query ICCID
cmd_iccid()
{
    at "$1" "AT+ICCID"
}

#query model name
cmd_cgmm()
{
    at "$1" "AT+CGMM"
}

#query manufacturer
cmd_cgmi()
{
    at "$1" "AT+CGMI"
}

#query revision
cmd_cgmr()
{
    at "$1" "AT+CGMR"
}

#query signal quality
cmd_csq()
{
    at "$1" "AT+CSQ"
}

#query cell info
cmd_zcellinfo_query()
{
    at "$1" "AT+ZCELLINFO?"
}

#query extended signal info
cmd_cesq()
{
    at "$1" "AT+CESQ"
}

#factory reset
cmd_atf_factory()
{
    at "$1" "AT&F"
}

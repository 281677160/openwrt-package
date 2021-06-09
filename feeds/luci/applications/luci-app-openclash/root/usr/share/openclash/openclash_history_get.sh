#!/bin/sh
. /usr/share/openclash/openclash_ps.sh

set_lock() {
   exec 881>"/tmp/lock/openclash_history_get.lock" 2>/dev/null
   flock -x 881 2>/dev/null
}

del_lock() {
   flock -u 881 2>/dev/null
   rm -rf "/tmp/lock/openclash_history_get.lock"
}

CURL_GROUP_CACHE="/tmp/openclash_history_gorup.json"
CURL_NOW_CACHE="/tmp/openclash_history_now.json"
CURL_CACHE="/tmp/openclash_history_curl.json"
CONFIG_FILE=$(unify_ps_cfgname)
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $4}' 2>/dev/null)
HISTORY_PATH="/etc/openclash/history/$CONFIG_NAME"
HISTORY_TMP="/tmp/openclash_history_tmp.yaml"
SECRET=$(uci get openclash.config.dashboard_password 2>/dev/null)
LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null |awk -F '/' '{print $1}' 2>/dev/null)
PORT=$(uci get openclash.config.cn_port 2>/dev/null)
LOG_FILE="/tmp/openclash.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
set_lock

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
   CONFIG_FILE=$(uci get openclash.config.config_path 2>/dev/null)
   CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
   HISTORY_PATH="/etc/openclash/history/$CONFIG_NAME"
fi

if [ -n "$(pidof clash)" ] && [ -f "$CONFIG_FILE" ]; then
   curl -m 5 --retry 2 -w %{http_code}"\n" -H "Authorization: Bearer ${SECRET}" -H "Content-Type:application/json" -X GET http://"$LAN_IP":"$PORT"/proxies > "$CURL_CACHE" 2>/dev/null
   if [ "$(sed -n '$p' "$CURL_CACHE" 2>/dev/null)" = "200" ]; then
      mkdir -p /etc/openclash/history 2>/dev/null
      cat "$CURL_CACHE" |jsonfilter -e '@["proxies"][@.type="Selector"]["name"]' > "$CURL_GROUP_CACHE" 2>/dev/null
      cat "$CURL_CACHE" |jsonfilter -e '@["proxies"][@.type="Selector"]["now"]' > "$CURL_NOW_CACHE" 2>/dev/null
      awk 'NR==FNR{a[i]=$0;i++}NR>FNR{print a[j]"#*#"$0;j++}' "$CURL_GROUP_CACHE" "$CURL_NOW_CACHE" > "$HISTORY_TMP" 2>/dev/null
      cmp -s "$HISTORY_TMP" "$HISTORY_PATH"
      if [ "$?" -ne "0" ] && [ -s "$HISTORY_TMP" ]; then
         mv "$HISTORY_TMP" "$HISTORY_PATH" 2>/dev/null
         echo "${LOGTIME} Groups History:【${CONFIG_NAME}】 Update Successful" >> $LOG_FILE
      fi
   else
      echo "${LOGTIME} Groups History:【${CONFIG_NAME}】 Update Faild" >> $LOG_FILE
   fi
fi
rm -rf /tmp/openclash_history_*  2>/dev/null
del_lock
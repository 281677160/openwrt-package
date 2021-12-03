#!/bin/sh
. /usr/share/openclash/log.sh
. /lib/functions.sh

urlencode() {
   local data
   if [ "$#" -eq 1 ]; then
      data=$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$1" "")
      if [ ! -z "$data" ]; then
         echo "$(echo ${data##/?} |sed 's/\//%2f/g' |sed 's/:/%3a/g' |sed 's/?/%3f/g' |sed 's/(/%28/g' |sed 's/)/%29/g' |sed 's/\^/%5e/g' |sed 's/=/%3d/g' |sed 's/|/%7c/g' |sed 's/+/%20/g')"
      fi
   fi
}

   RULE_FILE_NAME="$1"
   if [ "$1" == "netflix_domains" ]; then
      DOWNLOAD_PATH="https://cdn.jsdelivr.net/gh/vernesong/OpenClash@master/luci-app-openclash/root/usr/share/openclash/res/Netflix_Domains.list"
      RULE_FILE_DIR="/usr/share/openclash/res/Netflix_Domains.list"
      RULE_FILE_NAME="Netflix_Domains"
      RULE_TYPE="netflix"
   elif [ "$1" == "disney_domains" ]; then
      DOWNLOAD_PATH="https://cdn.jsdelivr.net/gh/vernesong/OpenClash@master/luci-app-openclash/root/usr/share/openclash/res/Disney_Plus_Domains.list"
      RULE_FILE_DIR="/usr/share/openclash/res/Disney_Plus_Domains.list"
      RULE_FILE_NAME="Disney_Plus_Domains"
      RULE_TYPE="disney"
   elif [ -z "$(grep "$RULE_FILE_NAME" /usr/share/openclash/res/rule_providers.list 2>/dev/null)" ]; then
      DOWNLOAD_PATH=$(grep -F "$RULE_FILE_NAME" /usr/share/openclash/res/game_rules.list |awk -F ',' '{print $2}' 2>/dev/null)
      RULE_FILE_DIR="/etc/openclash/game_rules/$RULE_FILE_NAME"
      RULE_TYPE="game"
   else
      DOWNLOAD_PATH=$(echo "$RULE_FILE_NAME" |awk -F ',' '{print $1$2}' 2>/dev/null)
      RULE_FILE_NAME=$(grep -F "$RULE_FILE_NAME" /usr/share/openclash/res/rule_providers.list |awk -F ',' '{print $NF}' 2>/dev/null)
      RULE_FILE_DIR="/etc/openclash/rule_provider/$RULE_FILE_NAME"
      RULE_TYPE="provider"
   fi

   if [ -z "$DOWNLOAD_PATH" ]; then
      LOG_OUT "Rule File【$RULE_FILE_NAME】Download Error!" && SLOG_CLEAN
      return 0
   fi

   TMP_RULE_DIR="/tmp/$RULE_FILE_NAME"
   TMP_RULE_DIR_TMP="/tmp/$RULE_FILE_NAME.tmp"
   [ "$RULE_TYPE" != "netflix" ] && [ "$RULE_TYPE" != "disney" ] && DOWNLOAD_PATH=$(urlencode "$DOWNLOAD_PATH")
   
   if [ "$RULE_TYPE" = "netflix" ]; then
      curl -sL --connect-timeout 5 --retry 2 "$DOWNLOAD_PATH" -o "$TMP_RULE_DIR" >/dev/null 2>&1
   elif [ "$RULE_TYPE" = "disney" ]; then
      curl -sL --connect-timeout 5 --retry 2 "$DOWNLOAD_PATH" -o "$TMP_RULE_DIR" >/dev/null 2>&1
   elif [ "$RULE_TYPE" = "game" ]; then
      if pidof clash >/dev/null; then
   	     curl -sL --connect-timeout 5 --retry 2 https://raw.githubusercontent.com/FQrabbit/SSTap-Rule/master/rules/"$DOWNLOAD_PATH" -o "$TMP_RULE_DIR" >/dev/null 2>&1
      fi
      if [ "$?" -ne "0" ] || ! pidof clash >/dev/null; then
         curl -sL --connect-timeout 5 --retry 2 https://cdn.jsdelivr.net/gh/FQrabbit/SSTap-Rule@master/rules/"$DOWNLOAD_PATH" -o "$TMP_RULE_DIR" >/dev/null 2>&1
      fi
   elif [ "$RULE_TYPE" = "provider" ]; then
      if pidof clash >/dev/null; then
   	     curl -sL --connect-timeout 5 --retry 2 https://raw.githubusercontent.com/"$DOWNLOAD_PATH" -o "$TMP_RULE_DIR" >/dev/null 2>&1
      fi
      if [ "$?" -ne "0" ] || ! pidof clash >/dev/null; then
         curl -sL --connect-timeout 5 --retry 2 https://cdn.jsdelivr.net/gh/"$(echo "$DOWNLOAD_PATH" |awk -F '/master' '{print $1}' 2>/dev/null)"@master"$(echo "$DOWNLOAD_PATH" |awk -F 'master' '{print $2}')" -o "$TMP_RULE_DIR" >/dev/null 2>&1
      fi
   fi

   if [ "$?" -eq "0" ] && [ -s "$TMP_RULE_DIR" ] && [ -z "$(grep "404: Not Found" "$TMP_RULE_DIR")" ] && [ -z "$(grep "Package size exceeded the configured limit" "$TMP_RULE_DIR")" ]; then
      if [ "$RULE_TYPE" = "game" ]; then
      	cat "$TMP_RULE_DIR" |sed '/^#/d' 2>/dev/null |sed '/^ *$/d' 2>/dev/null |awk '{print "  - "$0}' > "$TMP_RULE_DIR_TMP" 2>/dev/null
      	sed -i '1i\payload:' "$TMP_RULE_DIR_TMP" 2>/dev/null
      	cmp -s "$TMP_RULE_DIR_TMP" "$RULE_FILE_DIR"
      else
         cmp -s "$TMP_RULE_DIR" "$RULE_FILE_DIR"
      fi
         if [ "$?" -ne "0" ]; then
            if [ "$RULE_TYPE" = "game" ]; then
               mv "$TMP_RULE_DIR_TMP" "$RULE_FILE_DIR" >/dev/null 2>&1
            else
               mv "$TMP_RULE_DIR" "$RULE_FILE_DIR" >/dev/null 2>&1
            fi
            rm -rf "$TMP_RULE_DIR" >/dev/null 2>&1
            LOG_OUT "Rule File【$RULE_FILE_NAME】Download Successful!" && SLOG_CLEAN
            return 1
         else
            LOG_OUT "Rule File【$RULE_FILE_NAME】No Change, Do Nothing!" && SLOG_CLEAN
            rm -rf "$TMP_RULE_DIR" >/dev/null 2>&1
            rm -rf "$TMP_RULE_DIR_TMP" >/dev/null 2>&1
            return 2
         fi
   else
      rm -rf "$TMP_RULE_DIR" >/dev/null 2>&1
      LOG_OUT "Rule File【$RULE_FILE_NAME】Download Error!" && SLOG_CLEAN
      return 0
   fi
#!/bin/sh
. /lib/functions.sh
. /usr/share/openclash/openclash_ps.sh
. /usr/share/openclash/log.sh

CORE_TYPE="$1"
C_CORE_TYPE=$(uci -q get openclash.config.core_type)
[ -z "$CORE_TYPE" ] || [ "$1" = "one_key_update" ] && CORE_TYPE="Dev"
small_flash_memory=$(uci -q get openclash.config.small_flash_memory)
CPU_MODEL=$(uci -q get openclash.config.core_version)
RELEASE_BRANCH=$(uci -q get openclash.config.release_branch || echo "master")
github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)

[ ! -f "/tmp/clash_last_version" ] && /usr/share/openclash/clash_version.sh 2>/dev/null
if [ ! -f "/tmp/clash_last_version" ]; then
   LOG_OUT "Error: 【"$CORE_TYPE"】Core Version Check Error, Please Try Again Later..."
   sleep 3
   SLOG_CLEAN
   exit 0
fi

if [ "$small_flash_memory" != "1" ]; then
   dev_core_path="/etc/openclash/core/clash"
   tun_core_path="/etc/openclash/core/clash_tun"
   mkdir -p /etc/openclash/core
else
   dev_core_path="/tmp/etc/openclash/core/clash"
   tun_core_path="/tmp/etc/openclash/core/clash_tun"
   mkdir -p /tmp/etc/openclash/core
fi

case $CORE_TYPE in
	"TUN")
   CORE_CV=$($tun_core_path -v 2>/dev/null |awk -F ' ' '{print $2}')
   CORE_LV=$(sed -n 2p /tmp/clash_last_version 2>/dev/null)
   if [ -z "$CORE_LV" ]; then
      LOG_OUT "Error: 【"$CORE_TYPE"】Core Version Check Error, Please Try Again Later..."
      sleep 3
      SLOG_CLEAN
      exit 0
   fi
   ;;
   *)
   CORE_CV=$($dev_core_path -v 2>/dev/null |awk -F ' ' '{print $2}')
   CORE_LV=$(sed -n 1p /tmp/clash_last_version 2>/dev/null)
esac
   
[ "$C_CORE_TYPE" = "$CORE_TYPE" ] || [ -z "$C_CORE_TYPE" ] && if_restart=1

if [ "$CORE_CV" != "$CORE_LV" ] || [ -z "$CORE_CV" ]; then
   if [ "$CPU_MODEL" != 0 ]; then
      case $CORE_TYPE in
         "TUN")
            LOG_OUT "【TUN】Core Downloading, Please Try to Download and Upload Manually If Fails"
            if [ "$github_address_mod" != "0" ]; then
               if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
                  curl -sL -m 10 https://cdn.jsdelivr.net/gh/vernesong/OpenClash@"$RELEASE_BRANCH"/core-lateset/premium/clash-"$CPU_MODEL"-"$CORE_LV".gz -o /tmp/clash_tun.gz >/dev/null 2>&1
               else
                  curl -sL -m 10 "$github_address_mod"https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/core-lateset/premium/clash-"$CPU_MODEL"-"$CORE_LV".gz -o /tmp/clash_tun.gz >/dev/null 2>&1
               fi
            else
			         curl -sL -m 10 https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/core-lateset/premium/clash-"$CPU_MODEL"-"$CORE_LV".gz -o /tmp/clash_tun.gz >/dev/null 2>&1
			      fi
			      if [ "$?" != "0" ]; then
			         curl -sL -m 10 --retry 2 https://mirrors.tuna.tsinghua.edu.cn/osdn/storage/g/o/op/openclash/"$RELEASE_BRANCH"/core-lateset/premium/clash-"$CPU_MODEL"-"$CORE_LV".gz -o /tmp/clash_tun.gz >/dev/null 2>&1
			      fi
			   ;;
			   *)
			      LOG_OUT "【Dev】Core Downloading, Please Try to Download and Upload Manually If Fails"
			      if [ "$github_address_mod" != "0" ]; then
               if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
                  curl -sL -m 10 https://cdn.jsdelivr.net/gh/vernesong/OpenClash@"$RELEASE_BRANCH"/core-lateset/dev/clash-"$CPU_MODEL".tar.gz -o /tmp/clash.tar.gz >/dev/null 2>&1
               else
                  curl -sL -m 10 "$github_address_mod"https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/core-lateset/dev/clash-"$CPU_MODEL".tar.gz -o /tmp/clash.tar.gz >/dev/null 2>&1
               fi
            else
			         curl -sL -m 10 https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/core-lateset/dev/clash-"$CPU_MODEL".tar.gz -o /tmp/clash.tar.gz >/dev/null 2>&1
			      fi
			      if [ "$?" != "0" ]; then
			         curl -sL -m 10 --retry 2 https://mirrors.tuna.tsinghua.edu.cn/osdn/storage/g/o/op/openclash/"$RELEASE_BRANCH"/core-lateset/dev/clash-"$CPU_MODEL".tar.gz -o /tmp/clash.tar.gz >/dev/null 2>&1
			      fi
			esac

      if [ "$?" == "0" ]; then
         LOG_OUT "【"$CORE_TYPE"】Core Download Successful, Start Update..."
	       case $CORE_TYPE in
         	"TUN")
		        [ -s "/tmp/clash_tun.gz" ] && {
            gzip -d /tmp/clash_tun.gz >/dev/null 2>&1
		        rm -rf /tmp/clash_tun.gz >/dev/null 2>&1
			      rm -rf "$tun_core_path" >/dev/null 2>&1
			      chmod 4755 /tmp/clash_tun >/dev/null 2>&1
			      }
			   ;;
			   *)
			      [ -s "/tmp/clash.tar.gz" ] && {
               rm -rf "$dev_core_path" >/dev/null 2>&1
               tar zxvf /tmp/clash.tar.gz -C /tmp
				       rm -rf /tmp/clash.tar.gz >/dev/null 2>&1
				       chmod 4755 /tmp/clash >/dev/null 2>&1
            }
         esac
         if [ "$?" != "0" ]; then
            LOG_OUT "【"$CORE_TYPE"】Core Update Failed. Please Make Sure Enough Flash Memory Space And Try Again!"
            case $CORE_TYPE in
            "TUN")
               rm -rf /tmp/clash_tun >/dev/null 2>&1
				    ;;
				    *)
				       rm -rf /tmp/clash >/dev/null 2>&1
            esac
            sleep 3
            SLOG_CLEAN
            exit 0
         fi

			   case $CORE_TYPE in
         "TUN")
			      mv /tmp/clash_tun "$tun_core_path" >/dev/null 2>&1
			   ;;
			   *)
            mv /tmp/clash "$dev_core_path" >/dev/null 2>&1
			   esac
			   
         if [ "$?" == "0" ]; then
            LOG_OUT "【"$CORE_TYPE"】Core Update Successful!"
            if [ "$if_restart" -eq 1 ]; then
               uci -q set openclash.config.config_reload=0
         	     uci -q commit openclash
               if [ -z "$2" ] && [ "$1" != "one_key_update" ] && [ "$(unify_ps_prevent)" -eq 0 ]; then
                  /etc/init.d/openclash restart >/dev/null 2>&1 &
               fi
            else
               sleep 3
               SLOG_CLEAN
            fi
         else
            LOG_OUT "【"$CORE_TYPE"】Core Update Failed. Please Make Sure Enough Flash Memory Space And Try Again!"
            sleep 3
            SLOG_CLEAN
         fi
      else
         LOG_OUT "【"$CORE_TYPE"】Core Update Failed, Please Check The Network or Try Again Later!"
         sleep 3
         SLOG_CLEAN
      fi
   else
      LOG_OUT "No Compiled Version Selected, Please Select In Global Settings And Try Again!"
      sleep 3
      SLOG_CLEAN
   fi
else
   LOG_OUT "【"$CORE_TYPE"】Core Has Not Been Updated, Stop Continuing Operation!"
   sleep 3
   SLOG_CLEAN
fi

case $CORE_TYPE in
"TUN")
   rm -rf /tmp/clash_tun >/dev/null 2>&1
;;
*)
   rm -rf /tmp/clash >/dev/null 2>&1
esac
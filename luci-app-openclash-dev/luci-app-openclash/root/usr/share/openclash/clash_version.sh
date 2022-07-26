#!/bin/sh

set_lock() {
   exec 884>"/tmp/lock/openclash_clash_version.lock" 2>/dev/null
   flock -x 884 2>/dev/null
}

del_lock() {
   flock -u 884 2>/dev/null
   rm -rf "/tmp/lock/openclash_clash_version.lock"
}

CKTIME=$(date "+%Y-%m-%d-%H")
LAST_OPVER="/tmp/clash_last_version"
RELEASE_BRANCH=$(uci -q get openclash.config.release_branch || echo "master")
github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)
set_lock

if [ "$CKTIME" != "$(grep "CheckTime" $LAST_OPVER 2>/dev/null |awk -F ':' '{print $2}')" ]; then
   if [ "$github_address_mod" != "0" ]; then
      if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ]; then
         curl -sL -m 10 https://cdn.jsdelivr.net/gh/vernesong/OpenClash@"$RELEASE_BRANCH"/core_version -o $LAST_OPVER >/dev/null 2>&1
      elif [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ]; then
         curl -sL -m 10 https://fastly.jsdelivr.net/gh/vernesong/OpenClash@"$RELEASE_BRANCH"/core_version -o $LAST_OPVER >/dev/null 2>&1
      elif [ "$github_address_mod" == "https://raw.fastgit.org/" ]; then
         curl -sL -m 10 https://raw.fastgit.org/vernesong/OpenClash/"$RELEASE_BRANCH"/core_version -o $LAST_OPVER >/dev/null 2>&1
      else
         curl -sL -m 10 "$github_address_mod"https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/core_version -o $LAST_OPVER >/dev/null 2>&1
      fi
   else
      curl -sL -m 10 https://raw.githubusercontent.com/vernesong/OpenClash/"$RELEASE_BRANCH"/core_version -o $LAST_OPVER >/dev/null 2>&1
   fi
   
   if [ "$?" != "0" ] || [ -n "$(cat $LAST_OPVER |grep '<html>')" ]; then
      curl -sL -m 10 --retry 2 https://ftp.jaist.ac.jp/pub/sourceforge.jp/storage/g/o/op/openclash/"$RELEASE_BRANCH"/core_version -o $LAST_OPVER >/dev/null 2>&1
   fi
   
   if [ "$?" == "0" ] && [ -z "$(cat $LAST_OPVER |grep '<html>')" ]; then
      echo "CheckTime:$CKTIME" >>$LAST_OPVER
   else
      rm -rf $LAST_OPVER
   fi
fi
del_lock

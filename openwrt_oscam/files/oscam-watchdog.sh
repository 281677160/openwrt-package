#!/bin/sh

sleeptime=60
logfile="/var/log/oscam.log"
OSCAM_PATH=/usr/bin

[ -f  /tmp/oscam ] && 
{
	OSCAM_PATH=/tmp
	[ -x  /tmp/oscam ] ||  chmod +x /tmp/oscam
}

enable=$(uci get oscam.config.enabled 2>/dev/null)

oscam_log(){
	logrow=$(grep -c "" ${logfile})
	if [ $logrow -ge 500 ];then
		cat /dev/null > ${logfile}
		echo "$curtime Log条数超限，清空处理！" >> ${logfile}
	fi
}

while [ $enable -eq 1 ];
do
	oscam_log
	curtime=`date "+%H:%M:%S"`
	echo "$curtime online! "

	if ! pidof oscam>/dev/null; then
		${OSCAM_PATH}/oscam -b -r 2 -u -d 32
		echo "$curtime 重启服务！" >> ${logfile}
	fi

sleep ${sleeptime}
continue
done




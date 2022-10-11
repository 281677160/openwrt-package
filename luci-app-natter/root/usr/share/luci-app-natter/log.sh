#!/bin/sh

log_path=$(uci get natter.@base[0].log_path 2> /dev/null)

case $1 in
print)
	for i in $(ls -1 ${log_path} | grep natter | grep .log)
	do
		echo -e "\n======> $i <======"
		tail -n 30 ${log_path}/$i 2> /dev/null
		echo -e "======> END of $i <======"
	done
;;
del)
	rm -r ${log_path}/*.log
;;
esac

exit 0

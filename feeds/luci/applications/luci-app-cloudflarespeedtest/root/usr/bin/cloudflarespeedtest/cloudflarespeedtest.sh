#!/bin/sh

LOG_FILE='/var/log/cloudflarespeedtest.log'
IP_FILE='/usr/share/cloudflarespeedtestresult.txt'
IPV4_TXT='/usr/share/CloudflareSpeedTest/ip.txt'
IPV6_TXT='/usr/share/CloudflareSpeedTest/ipv6.txt'

function get_global_config(){
	while [[ "$*" != "" ]]; do
		eval ${1}='`uci get cloudflarespeedtest.global.$1`' 2>/dev/null
		shift
	done
}

function get_servers_config(){
	while [[ "$*" != "" ]]; do
		eval ${1}='`uci get cloudflarespeedtest.servers.$1`' 2>/dev/null
		shift
	done
}

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$LOG_FILE
}

function read_config(){
	get_global_config "enabled" "speed" "custome_url" "threads" "tl" "tll" "ipv6_enabled" "advanced" "proxy_mode"
	get_servers_config "ssr_services" "ssr_enabled" "passwall_enabled" "passwall_services" "DNS_enabled"
}

function  speed_test(){

	rm -rf $LOG_FILE

	command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${custome_url} -o ${IP_FILE}"

	if [ $ipv6_enabled -eq "1" ] ;then
		command="${command} -f ${IPV6_TXT} -ipv6"
	else
		command="${command} -f ${IPV4_TXT}"
	fi

	if [ $advanced -eq "1" ] ; then
		command="${command} -tl ${tl} -tll ${tll} -n ${threads}"
	else
		command="${command} -tl 200 -tll 40 -n 200"
	fi
	
	ssr_original_server=$(uci get shadowsocksr.@global[0].global_server 2>/dev/null)
	ssr_original_run_mode=$(uci get shadowsocksr.@global[0].run_mode 2>/dev/null)
	if [ $ssr_original_server != "nil" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set shadowsocksr.@global[0].global_server="nil"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set shadowsocksr.@global[0].run_mode="gfw"
		fi
		uci commit shadowsocksr
		/etc/init.d/shadowsocksr restart
	fi

	passwall_server_enabled=$(uci get passwall.@global[0].enabled 2>/dev/null)
	passwall_original_run_mode=$(uci get passwall.@global[0].tcp_proxy_mode 2>/dev/null)
	if [ $passwall_server_enabled -eq "1" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set passwall.@global[0].enabled="0"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set passwall.@global[0].tcp_proxy_mode="gfwlist"
		fi
		uci commit passwall
		/etc/init.d/passwall  restart 2>/dev/null
	fi

	echo $command  >> $LOG_FILE 2>&1 
	echolog "-----------start----------" 
	$command >> $LOG_FILE 2>&1
	echolog "-----------end------------"
}

function ip_replace(){

	# 获取最快 IP（从 result.csv 结果文件中获取第一个 IP）
	bestip=$(sed -n "2,1p" $IP_FILE | awk -F, '{print $1}')
	[[ -z "${bestip}" ]] && echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..." && exit 0

	alidns_ip

	ssr_best_ip
	
	passwall_best_ip
	
}

function passwall_best_ip(){
	if [ $passwall_server_enabled -eq '1' ] ; then
		echolog "设置passwall代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set passwall.@global[0].enabled="${passwall_server_enabled}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set passwall.@global[0].tcp_proxy_mode="${passwall_original_run_mode}"
		fi	
		uci commit passwall
	fi

	if [ $passwall_enabled -eq "1" ] ;then
		echolog "设置passwall IP"
		for ssrname in $passwall_services
		do
			echo $ssrname
			uci set passwall.$ssrname.address="${bestip}"
		done
		uci commit passwall
 		if [ $passwall_server_enabled -eq "1" ] ;then
			/etc/init.d/passwall restart 2>/dev/null
			echolog "passwall重启完成"
		fi
	fi
}

function ssr_best_ip(){

	if [ $ssr_enabled -eq "1" ] ;then
		echolog "设置ssr IP"
		for ssrname in $ssr_services
		do
			echo $ssrname
			uci set shadowsocksr.$ssrname.server="${bestip}"
			uci set shadowsocksr.$ssrname.ip="${bestip}"
		done
		uci commit shadowsocksr
		 	
	fi

	if [ $ssr_original_server != 'nil' ] ; then
		echolog "设置ssr代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set shadowsocksr.@global[0].global_server="${ssr_original_server}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set  shadowsocksr.@global[0].run_mode="${ssr_original_run_mode}"
		fi	
		/etc/init.d/shadowsocksr restart 2 >/dev/null
		echolog "ssr重启完成"
	fi
}

function alidns_ip(){
	if [ $DNS_enabled -eq "1" ] ;then
		get_servers_config "DNS_type" "app_key" "app_secret" "main_domain" "sub_domain" "line"
		if [ $DNS_type == "aliyu" ] ;then
			/usr/bin/cloudflarespeedtest/aliddns.sh $app_key $app_secret $main_domain $sub_domain $line $ipv6_enabled $bestip
			echolog "更新阿里云DNS完成"
		fi		
	fi
}

read_config

# 启动参数
if [ "$1" ] ;then
	[ $1 == "start" ] && speed_test && ip_replace
	[ $1 == "test" ] && speed_test
	[ $1 == "replace" ] && ip_replace
	exit
fi
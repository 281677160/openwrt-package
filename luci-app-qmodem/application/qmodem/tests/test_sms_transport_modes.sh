#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
backend="$ROOT/application/qmodem_smsd/src/main.c"
migration="$ROOT/application/qmodem/files/etc/uci-defaults/91-qmodem-use-ubus"
docs="$ROOT/docs/wiki/SIP-SMS-VoIP-Configuration.zh-cn.md"

grep -Fq 'cfg->use_ubus ? "database_poll" : "direct"' "$backend"
grep -Fq 'if (strcmp(mode_name, "direct")) {' "$backend"
grep -Fq 'qmodem.$section.sms_mode=direct' "$migration"
grep -Fq '/etc/init.d/qmodem-smsd enable' "$docs"
grep -Fq '/etc/init.d/qmodem-smsd restart' "$docs"
if grep -Fq '/etc/init.d/qmodem_smsd' "$docs"; then
	echo 'obsolete qmodem_smsd service name remains in documentation' >&2
	exit 1
fi

echo 'PASS: legacy SMS transport fallback and service names are consistent'

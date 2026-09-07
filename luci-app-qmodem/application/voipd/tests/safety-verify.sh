#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

QMODEM_VOIP_JOURNAL=$fixture/journal
QMODEM_VOIP_ADAPTER=$fixture/missing-adapter
. "$root/files/usr/lib/qmodem_voip/modem_safety.sh"

slot=2-1.1
media_method=serial_pcm
media_qdai=x,0,0,4,0,0,1,1
media_qpcmv_cfg=8000,20
media_qpcmv=1,0
media_qaudmod=2
ims=0
voice_disable=0
qpcmv=0
qpcmv_cfg=8000,20
qdai=x,0,0,4,0,0,0,0
qaudmod=0
gps_outport=none
usbcfg=0x2c7c,0x0801,1,1,1,1,1,0,0
qmodem_voip_write_journal enabled

qmodem_voip_adapter_rediscover() { return 0; }
qmodem_voip_at()
{
	printf '%s\n' "$1" >>"$fixture/commands"
	case $1 in
		'AT+QCFG="ims"') printf '%s' 1 ;;
		'AT+QCALLCFG="voice_disable"') printf '%s' 2 ;;
		'AT+QPCMV?') printf '%s' "${TEST_QPCMV:-1,0}" ;;
		'AT+QAUDMOD?') printf '%s' 2 ;;
		'AT+QCFG="usbcfg"') printf '%s' '0x2c7c,0x0801,1,1,1,1,1,0,0' ;;
		'AT+QDAI?') printf '%s' "${TEST_QDAI:-x,0,0,4,0,0,1,1}" ;;
		'AT+QAUDCFG="qpcmv_cfg"') printf '%s' '8000,20' ;;
		AT+QAUDMOD=*|AT+QAUDCFG=*|AT+QPCMV=*) return 0 ;;
		*) return 1 ;;
	esac
}

: >"$fixture/commands"
qmodem_voip_verify
if grep -Ev '(\?|QCFG="(ims|usbcfg)"|QCALLCFG="voice_disable"|QAUDCFG="qpcmv_cfg")$' \
	"$fixture/commands" | grep . >/dev/null; then
	echo 'FAIL: verify mutated modem state' >&2
	exit 1
fi

TEST_QPCMV=0
export TEST_QPCMV
if qmodem_voip_verify; then
	echo 'FAIL: verify accepted drifted QPCMV state' >&2
	exit 1
fi
unset TEST_QPCMV

: >"$fixture/commands"
qmodem_voip_arm
[ "$(cat "$fixture/commands")" = 'AT+QDAI?
AT+QPCMV?' ] || {
	echo 'FAIL: active-call arm replayed an already-correct PCM stream' >&2
	exit 1
}

TEST_QDAI=x,0,0,5,0,1,1,1
export TEST_QDAI
: >"$fixture/commands"
if qmodem_voip_arm; then
	echo 'FAIL: active-call arm accepted a drifted reboot-applied QDAI state' >&2
	exit 1
fi
[ "$(cat "$fixture/commands")" = 'AT+QDAI?' ] || {
	echo 'FAIL: active-call arm mutated forwarding after QDAI drift' >&2
	exit 1
}
unset TEST_QDAI

TEST_QPCMV=0
export TEST_QPCMV
: >"$fixture/commands"
qmodem_voip_arm
[ "$(cat "$fixture/commands")" = 'AT+QDAI?
AT+QPCMV?
AT+QAUDMOD=2
AT+QAUDCFG="qpcmv_cfg",8000,20
AT+QPCMV=1,0' ] || {
	echo 'FAIL: active-call arm did not repair drifted QPCMV' >&2
	exit 1
}
unset TEST_QPCMV

qmodem_voip_at() { echo disconnected >>"$fixture/commands"; return 1; }
qmodem_voip_adapter_wait_reenumeration()
{
	[ "$1:$2:$3" = '2-1.1:0:60' ] || return 1
	echo reenumerated >>"$fixture/commands"
}
: >"$fixture/commands"
qmodem_voip_reboot_and_wait 2-1.1 0
[ "$(cat "$fixture/commands")" = 'disconnected
reenumerated' ] || {
	echo 'FAIL: reboot did not use re-enumeration as its success signal' >&2
	exit 1
}

: >"$fixture/capabilities.json"
QMODEM_VOIP_SUPPORTS=$fixture/capabilities.json
qmodem_voip_json()
{
	case $1 in
		'@.schema') printf '%s' 1 ;;
		'@.modems[*].model') printf '%s' UAC-MODEM ;;
		'@.modems[0].firmware') printf '%s' UAC-FW ;;
		'@.modems[0].usb_id') printf '%s' 2c7c:ffff ;;
		'@.modems[0].adb_unlock') printf '%s' false ;;
		'@.modems[0].audio.method') printf '%s' uac ;;
		'@.modems[0].audio.uac') printf '%s' true ;;
		'@.modems[0].audio.qpcmv') printf '%s' "$TEST_UAC_QPCMV" ;;
		'@.modems[0].audio.qaudmod') printf '%s' 2 ;;
		*) return 1 ;;
	esac
}

TEST_UAC_QPCMV=1,2
qmodem_voip_load_capability UAC-MODEM UAC-FW 2c7c:ffff
[ "$media_method:$media_qpcmv" = 'uac:1,2' ] || {
	echo 'FAIL: documented QPCMV UAC option was not accepted' >&2
	exit 1
}

TEST_UAC_QPCMV=1,3
if qmodem_voip_load_capability UAC-MODEM UAC-FW 2c7c:ffff; then
	echo 'FAIL: PCIe QPCMV option was accepted as UAC' >&2
	exit 1
fi

echo 'PASS: call-time safety verification is read-only and fails closed'

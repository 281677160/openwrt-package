#!/bin/sh
set -eu

source=/tmp/libqvoice_media_gate.so
target=/etc/qmodem_voip/libqvoice_media_gate.so
dropin_dir=/etc/systemd/system/quectel-voice-server.service.d
dropin=$dropin_dir/qmodem-voip-media-gate.conf
preload=LD_PRELOAD=/etc/qmodem_voip/libqvoice_media_gate.so
changed=0

mkdir -p /etc/qmodem_voip "$dropin_dir"
if ! { [ -s "$target" ] && cmp -s "$source" "$target" &&
	[ -s "$dropin" ] && grep -qxF "Environment=$preload" "$dropin"; }; then
	changed=1
	cp "$source" "$target.new"
	chmod 0755 "$target.new"
	mv -f "$target.new" "$target"
	printf '%s\n' '[Service]' "Environment=$preload" > "$dropin.new"
	chmod 0644 "$dropin.new"
	mv -f "$dropin.new" "$dropin"
fi
rm -f "$source"
systemctl daemon-reload

pid=$(systemctl show quectel-voice-server.service -p MainPID --value || true)
case "$pid" in ''|*[!0-9]*) pid=0 ;; esac
if [ "$changed" = 1 ] || [ "$pid" -le 1 ] ||
	! tr '\000' '\n' < "/proc/$pid/environ" | grep -qxF "$preload"; then
	systemctl restart quectel-voice-server.service
fi
rm -f /tmp/install_qmodem_voip_media_gate.sh

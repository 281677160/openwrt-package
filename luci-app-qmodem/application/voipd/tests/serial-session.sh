#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=${TMPDIR:-/tmp}/qmodem-voip-serial-session-$$
trap 'rm -f "$fixture"' EXIT HUP INT TERM

${CC:-cc} -DQMODEM_VOIP_HOST_TEST -std=c11 -Wall -Wextra -Werror \
	-I"$root/src" "$root/tests/serial-session-fixture.c" \
	"$root/src/media_serial.c" \
	-lm -pthread -o "$fixture"
"$fixture"

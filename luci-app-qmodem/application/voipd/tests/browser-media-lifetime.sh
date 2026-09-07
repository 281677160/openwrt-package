#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

${CC:-cc} -DQMODEM_VOIP_HOST_TEST -std=c11 -Wall -Wextra -Werror \
	-I"$ROOT/src" "$ROOT/tests/browser-media-lifetime-fixture.c" \
	"$ROOT/src/browser_media.c" "$ROOT/src/media_core.c" -lm -pthread \
	-o "$TMP/browser-media-lifetime"
"$TMP/browser-media-lifetime"

grep -q 'lws_service_tsi(browser->context, -1, 0)' "$ROOT/src/browser_media.c"
grep -q 'QMODEM_VOIP_BROWSER_FRAME_SIZE, 0, NULL, 0' "$ROOT/src/browser_media.c"
grep -q 'connection->uplink_length += length' "$ROOT/src/browser_media.c"
! grep -q 'cookie_value' "$ROOT/src/browser_media.c"

echo 'PASS: browser media lifetime and nonblocking service contract'

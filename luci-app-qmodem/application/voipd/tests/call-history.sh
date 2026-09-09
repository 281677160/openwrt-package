#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BUILD_DIR=$(mktemp -d)
HOST_DIR=${OPENWRT_HOST_DIR:-$ROOT/../../../../immortalwrt/staging_dir/host}
trap 'rm -rf "$BUILD_DIR"' EXIT

${CC:-cc} -std=c11 -Wall -Wextra -Werror -I"$ROOT/src" -I"$HOST_DIR/include" \
	"$ROOT/tests/call-history-fixture.c" "$ROOT/src/call_history.c" \
	-o "$BUILD_DIR/call-history" "$HOST_DIR/lib/libjson-c.a"
"$BUILD_DIR/call-history" "$BUILD_DIR/history.json"
[ "$(stat -c %a "$BUILD_DIR/history.json")" = 600 ]

echo 'PASS: bounded atomic call history and missed-call classification'

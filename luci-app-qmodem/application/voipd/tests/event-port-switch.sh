#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

${CC:-cc} -std=c11 -Wall -Wextra -Werror -I"$ROOT/src" \
	"$ROOT/tests/event-port-switch-fixture.c" "$ROOT/src/call_state.c" \
	-o "$TMP/event-port-switch"
"$TMP/event-port-switch"

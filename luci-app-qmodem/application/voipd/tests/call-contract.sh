#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

${CC:-cc} -std=c11 -Wall -Wextra -Werror \
	-I"$ROOT/src" \
	"$ROOT/tests/call-contract-fixture.c" "$ROOT/src/call_state.c" \
	-o "$BUILD_DIR/call-contract"
"$BUILD_DIR/call-contract"

echo 'PASS: call identity, backend duration, and DTMF contract'

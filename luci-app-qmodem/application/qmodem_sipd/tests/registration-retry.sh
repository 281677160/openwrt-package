#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

${CC:-cc} -std=c11 -Wall -Wextra -Werror -I"$ROOT/src" \
	"$ROOT/tests/registration-retry-fixture.c" \
	"$ROOT/src/sip_registration.c" -o "$TMPDIR/registration-retry"
"$TMPDIR/registration-retry"

echo 'PASS: outbound SIP registration retry backoff'

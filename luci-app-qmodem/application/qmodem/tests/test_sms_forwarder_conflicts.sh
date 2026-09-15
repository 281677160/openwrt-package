#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
legacy="$ROOT/application/sms_forwarder/Makefile"
next="$ROOT/application/sms_forwarder_next/Makefile"

grep -qx 'PKG_CONFLICTS:=sms-forwarder-next' "$legacy"
grep -qx 'PKG_CONFLICTS:=sms-forwarder' "$next"

grep -Fq 'files/etc/init.d/sms_forwarder $(1)/etc/init.d/' "$legacy"
grep -Fq 'files/sms_forwarder.init $(1)/etc/init.d/sms_forwarder' "$next"

echo 'PASS: SMS forwarder packages declare their shared init script conflict'

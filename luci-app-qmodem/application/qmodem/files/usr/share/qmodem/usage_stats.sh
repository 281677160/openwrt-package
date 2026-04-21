#!/bin/sh

. /lib/functions.sh
. /usr/share/qmodem/modem_util.sh

MIN_INTERVAL=60
DEFAULT_INTERVAL=300

sanitize_interval()
{
    local interval="$1"

    case "$interval" in
        ''|*[!0-9]*)
            interval="$DEFAULT_INTERVAL"
            ;;
    esac

    [ "$interval" -lt "$MIN_INTERVAL" ] && interval="$MIN_INTERVAL"
    echo "$interval"
}

load_vendor_script()
{
    local vendor="$1"
    local vendor_script_prefix="/usr/share/qmodem/vendor"
    local dynamic_load_json="$vendor_script_prefix/dynamic_load.json"
    local vendor_file="${vendor_script_prefix}/$(jq -r --arg vendor "$vendor" '.[$vendor]' "$dynamic_load_json" 2>/dev/null)"

    . /usr/share/qmodem/generic.sh
    [ -n "$vendor" ] && [ -f "$vendor_file" ] && . "$vendor_file"
}

write_device_usage_stats()
{
    local config_section="$1"
    local state manufacturer vendor_key at_port override_at_port use_ubus

    config_load qmodem

    config_get state "$config_section" state
    [ "$state" = "disabled" ] && return 0

    config_get manufacturer "$config_section" manufacturer
    vendor_key=$(echo "$manufacturer" | tr '[:upper:]' '[:lower:]')
    [ "$vendor_key" = "quectel" ] || return 0

    config_get at_port "$config_section" at_port
    config_get override_at_port "$config_section" override_at_port
    [ -n "$override_at_port" ] && at_port="$override_at_port"
    [ -n "$at_port" ] || return 0

    config_get use_ubus "$config_section" use_ubus
    use_ubus_flag=""
    [ "$use_ubus" = "1" ] && use_ubus_flag="-u"

    load_vendor_script "$vendor_key"
    if ! write_usage_stats; then
        logger -t qmodem_usage_stats "failed to persist usage stats for $config_section"
    fi
}

loop()
{
    local config_section="$1"
    local interval

    interval=$(sanitize_interval "$2")
    [ -n "$config_section" ] || exit 1

    while true; do
        write_device_usage_stats "$config_section"
        sleep "$interval"
    done
}

case "$1" in
    loop)
        loop "$2" "$3"
        ;;
    run_once)
        [ -n "$2" ] || exit 1
        write_device_usage_stats "$2"
        ;;
    *)
        echo "Usage: $0 {loop <config_section> <interval>|run_once <config_section>}" >&2
        exit 1
        ;;
esac

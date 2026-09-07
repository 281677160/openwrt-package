#!/usr/bin/env python3
"""Count and echo live PCMA RTP, splitting calls on receive gaps."""

import argparse
import audioop
import json
import math
import socket
import struct
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=40000)
    parser.add_argument("--timeout", type=float, default=90.0)
    parser.add_argument("--call-gap", type=float, default=3.0)
    parser.add_argument("--peer")
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((args.bind, args.port))
    sock.settimeout(0.005)
    started = time.monotonic()
    last_packet = None
    calls = []
    sequence = 0
    timestamp = 0
    sent_packets = 0
    next_send = started
    peer = (args.peer, args.port) if args.peer else None
    linear_tone = b"".join(
        struct.pack("!h", int(6000 * math.sin(2 * math.pi * 440 * sample / 8000)))
        for sample in range(160)
    )
    tone = audioop.lin2alaw(linear_tone, 2)

    while time.monotonic() - started < args.timeout:
        now = time.monotonic()
        if peer and now >= next_send:
            header = struct.pack("!BBHII", 0x80, 8, sequence, timestamp, 0x514D5650)
            sock.sendto(header + tone, peer)
            sequence = (sequence + 1) & 0xFFFF
            timestamp = (timestamp + 160) & 0xFFFFFFFF
            sent_packets += 1
            next_send += 0.02
            if next_send < now - 0.02:
                next_send = now
        try:
            packet, source = sock.recvfrom(2048)
        except socket.timeout:
            continue
        now = time.monotonic()
        if peer is None:
            peer = source
            next_send = now
        if last_packet is None or now - last_packet >= args.call_gap:
            calls.append({"packets": 0, "bytes": 0, "peak_rms": 0})
        last_packet = now
        if len(packet) < 12 or packet[0] >> 6 != 2:
            continue
        header = 12 + (packet[0] & 0x0F) * 4
        payload = packet[header:]
        if not payload:
            continue
        call = calls[-1]
        call["packets"] += 1
        call["bytes"] += len(payload)
        call["peak_rms"] = max(call["peak_rms"], audioop.rms(audioop.alaw2lin(payload, 2), 2))

    result = {
        "call_count": len(calls),
        "sent_packets": sent_packets,
        "calls": [
            {"packets": call["packets"], "bytes": call["bytes"], "peak_rms": call["peak_rms"]}
            for call in calls
        ],
    }
    print(json.dumps(result, separators=(",", ":")))
    return 0 if len(calls) >= 2 and all(call["packets"] > 0 for call in calls[:2]) else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
AttachClip for Thunderbird — scripts/smoke_test.py
===================================================

End-to-end smoke test for the macOS helper binary. Exercises the
full session lifecycle (begin_session → begin_file → write_chunk →
end_file → on-disk verify → commit_clipboard → clear_cache) without
a real Thunderbird instance, but with real Foundation/AppKit on macOS.

Usage:
    ./scripts/smoke_test.py                            # uses default build path
    ./scripts/smoke_test.py --helper /abs/bin/...      # custom binary

Exit code is 0 on full success, non-zero on the first failure.
"""

import argparse
import base64
import json
import os
import struct
import subprocess
import sys


DEFAULT_HELPER = (
    "native-host/macos/.build/release/attachclip-host"
)


def frame(obj):
    j = json.dumps(obj).encode("utf-8")
    return struct.pack("<I", len(j)) + j


def read_frame(stream):
    head = stream.read(4)
    if len(head) < 4:
        return None
    n = struct.unpack("<I", head)[0]
    body = stream.read(n)
    return json.loads(body.decode("utf-8"))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--helper", default=DEFAULT_HELPER,
                   help="path to the attachclip-host binary")
    p.add_argument("--sample-size", type=int, default=6600,
                   help="bytes per file to round-trip")
    args = p.parse_args()

    helper = os.path.abspath(args.helper)
    if not os.path.exists(helper):
        print(f"helper not found: {helper}", file=sys.stderr)
        return 2

    sample = b"hello-attachclip-from-smoke-test\n" * (
        args.sample_size // 31 + 1
    )
    sample = sample[: args.sample_size]

    proc = subprocess.Popen(
        [helper],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=0,
    )

    def send(obj):
        proc.stdin.write(frame(obj))
        proc.stdin.flush()

    def step(name, payload):
        send(payload)
        r = read_frame(proc.stdout)
        print(f"[{name:5}] {json.dumps(r, sort_keys=True)}")
        if not r or not r.get("ok"):
            raise SystemExit(f"step {name} failed: {r}")
        return r

    try:
        step("ping ", {"type": "ping", "v": 1, "nonce": "h0"})
        sess = step("sess ", {"type": "begin_session", "v": 1,
                              "nonce": "h1"})
        sessionId = sess["sessionId"]

        begin = step("begin", {"type": "begin_file", "v": 1,
                               "nonce": "h2",
                               "sessionId": sessionId,
                               "fileId": "fA",
                               "suggestedName": "smoke.txt",
                               "contentType": "text/plain",
                               "size": len(sample)})
        abs_path = begin["path"]

        sent = 0
        chunk_id = 0
        CHUNK = 1024
        while sent < len(sample):
            piece = sample[sent:sent + CHUNK]
            step("chunk", {"type": "write_chunk", "v": 1,
                           "nonce": f"h3-{chunk_id}",
                           "sessionId": sessionId,
                           "fileId": "fA",
                           "chunkId": chunk_id,
                           "data": base64.b64encode(piece).decode("ascii")})
            sent += len(piece)
            chunk_id += 1

        end = step("end  ", {"type": "end_file", "v": 1,
                             "nonce": "h4",
                             "sessionId": sessionId,
                             "fileId": "fA",
                             "bytesWritten": sent})
        assert end["size"] == sent, "size mismatch"

        with open(abs_path, "rb") as f:
            on_disk = f.read()
        match = on_disk == sample
        print(f"[fs   ] read back {len(on_disk)} bytes; "
              f"matches sample → {match}")
        if not match:
            return 3

        step("comm ", {"type": "commit_clipboard", "v": 1,
                       "nonce": "h5",
                       "sessionId": sessionId,
                       "fileIds": ["fA"]})

        step("clr  ", {"type": "clear_cache", "v": 1,
                       "nonce": "h6", "olderThanHours": 0})

        print("\nHAPPY PATH FULL FLOW \u2705")
        return 0
    finally:
        try:
            proc.stdin.close()
        except OSError:
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())

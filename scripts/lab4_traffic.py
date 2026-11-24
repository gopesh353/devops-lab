#!/usr/bin/env python3
"""Small traffic generator used by the blue-green and canary demos.

It records the X-App-Version header so the scripts can prove which version
served each request. No third-party packages are required.
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request


def request_once(url, host, timeout):
    headers = {}
    if host:
        headers["Host"] = host
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        version = response.headers.get("X-App-Version", "unknown")
        return response.status, version


def run(url, host, count, duration, interval, output):
    counts = {}
    statuses = {}
    failures = 0
    total = 0
    started = time.time()

    try:
        while True:
            if count is not None and total >= count:
                break
            if duration is not None and time.time() - started >= duration:
                break

            try:
                status, version = request_once(url, host, timeout=5)
            except (urllib.error.URLError, TimeoutError, OSError):
                failures += 1
                status, version = 0, "error"
            else:
                statuses[str(status)] = statuses.get(str(status), 0) + 1
                counts[version] = counts.get(version, 0) + 1
            total += 1

            if interval:
                time.sleep(interval)
    except KeyboardInterrupt:
        pass

    result = {
        "total": total,
        "failed": failures,
        "versions": counts,
        "statuses": statuses,
        "duration_seconds": round(time.time() - started, 2),
    }
    text = json.dumps(result, indent=2, sort_keys=True)
    print(text)
    if output:
        with open(output, "w", encoding="utf-8") as handle:
            handle.write(text + "\n")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    probe = sub.add_parser("probe", help="continuous requests for a fixed time")
    probe.add_argument("--url", required=True)
    probe.add_argument("--host", default="")
    probe.add_argument("--duration", type=float, default=45)
    probe.add_argument("--interval", type=float, default=0.2)
    probe.add_argument("--output", default="")

    sample = sub.add_parser("sample", help="a fixed number of requests")
    sample.add_argument("--url", required=True)
    sample.add_argument("--host", default="")
    sample.add_argument("--count", type=int, default=100)
    sample.add_argument("--interval", type=float, default=0.05)
    sample.add_argument("--output", default="")

    args = parser.parse_args()
    if args.command == "probe":
        run(args.url, args.host, None, args.duration, args.interval, args.output)
    else:
        run(args.url, args.host, args.count, None, args.interval, args.output)


if __name__ == "__main__":
    sys.exit(main())

"""Serial console validation (boot-phase truth SSH cannot see).

Passive watcher for the debug UART: verifies the boot chain produces kernel
output, systemd starts, and a login prompt appears — plus panic/oops scan.

Usage:
    python3 -m acadia_validation.serial_console --port /dev/ttyUSB0 \
        [--baud 115200] [--timeout 120] [--reboot-cmd "echo via relay"]
"""

from __future__ import annotations

import argparse
import sys
import time


def watch(port: str, baud: int = 115200, timeout_s: int = 120,
          expect_login: str = "login:",
          reboot_command: str | None = None) -> int:
    try:
        import serial  # pyserial
    except ModuleNotFoundError:
        print("error: pyserial not installed — run 'make setup' "
              "(or: pip install pyserial)", file=sys.stderr)
        return 2

    print(f"[serial] opening {port} @ {baud} for up to {timeout_s}s")
    try:
        ser = serial.Serial(port, baud, timeout=1)
    except Exception as exc:  # noqa: BLE001
        print(f"error: cannot open {port}: {exc}", file=sys.stderr)
        return 2

    if reboot_command:
        import subprocess
        print(f"[serial] issuing reboot: {reboot_command}")
        subprocess.run(reboot_command, shell=True, check=False)

    seen_boot = False
    seen_login = False
    panics: list[str] = []
    import time
    deadline = time.monotonic() + timeout_s
    buf = ""
    while time.monotonic() < deadline:
        chunk = ser.read(1024).decode("utf-8", "replace")
        if chunk:
            buf += chunk
            if not seen_boot and ("Booting Linux" in buf or "Linux version" in buf
                                  or "systemd" in buf):
                seen_boot = True
                print("[serial] boot output detected")
            for needle in ("Kernel panic", "Oops:", "BUG: kernel"):
                if needle in chunk:
                    panics.append(needle)
            if expect_login in buf:
                seen_login = True
                print("[serial] login prompt reached")
                break
    ser.close()

    problems = []
    if not seen_boot:
        problems.append("no boot output observed (chain stalled before "
                        "kernel/systemd?)")
    if panics:
        problems.append(f"kernel faults seen: {panics}")
    if seen_boot and not seen_login:
        problems.append(f"boot output seen but no '{expect_login}' prompt "
                        f"within {timeout_s}s")
    if problems:
        print(f"FAIL [serial] {'; '.join(problems)}")
        return 1
    print("[serial] PASS — boot chain reached console login prompt, "
          "no panics")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(
        prog="acadia-serial",
        description="Passive boot-chain validation over the UART console.")
    p.add_argument("--port", required=True, help="serial device "
                   "(e.g. /dev/ttyUSB0)")
    p.add_argument("--baud", type=int, default=115200)
    p.add_argument("--timeout", type=int, default=120,
                   help="seconds to wait for the login prompt")
    p.add_argument("--reboot-command", default=None,
                   help="optional host command issued first (power relay, "
                        "ssh reboot, ...) so the boot can be observed")
    args = p.parse_args(argv)
    return watch(args.port, args.baud, args.timeout,
                 reboot_command=args.reboot_command)


if __name__ == "__main__":
    raise SystemExit(main())
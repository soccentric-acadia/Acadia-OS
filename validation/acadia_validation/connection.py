"""SSH connection to the booted Acadia target (paramiko, loaded lazily).

One authenticated connection multiplexes every check, so the suite
authenticates exactly once regardless of how many commands it runs.
"""

from __future__ import annotations

import shlex
import time
from dataclasses import dataclass, field


class TargetUnreachable(Exception):
    """SSH connect/auth failed — the device did not present the image."""


class PrivilegeUnavailable(Exception):
    """A root-level check ran without passwordless sudo on the target."""


@dataclass
class ExecResult:
    cmd: str
    stdout: str = ""
    stderr: str = ""
    exit_code: int = -1
    timed_out: bool = False

    @property
    def ok(self) -> bool:
        return self.exit_code == 0 and not self.timed_out


class TargetConnection:
    """Thin, robust wrapper over one paramiko SSH connection."""

    def __init__(self, cfg) -> None:
        self.cfg = cfg
        self._client = None
        self._sudo_ok: bool | None = None
        self._cache: dict = field(default={})

    # ── lifecycle ────────────────────────────────────────────────────────
    def connect(self) -> None:
        import paramiko  # lazy: `--list` must work without it

        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                self.cfg.host,
                port=self.cfg.port,
                username=self.cfg.user,
                password=self.cfg.password,
                key_filename=self.cfg.key_file,
                timeout=self.cfg.connect_timeout,
                allow_agent=False,
                look_for_keys=False,
            )
        except Exception as exc:  # noqa: BLE001 — report any auth/conn error
            raise TargetUnreachable(
                f"{self.cfg.host}:{self.cfg.port} as {self.cfg.user!r} — {exc}"
            ) from exc
        self._client = client

    def close(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
            except Exception:  # noqa: BLE001
                pass
            self._client = None

    # ── execution ────────────────────────────────────────────────────────
    def run(self, cmd: str, timeout: float | None = None,
            sudo: bool = False) -> ExecResult:
        """Run a shell command on the target and capture its result."""
        if sudo:
            if self._sudo_ok is None:
                probe = self._exec("sudo -n true", timeout=10.0)
                self._sudo_ok = probe.ok
            if not self._sudo_ok:
                raise PrivilegeUnavailable(
                    "passwordless sudo not available on target")
            cmd = f"sudo -n {cmd}"
        return self._exec(cmd, timeout or self.cfg.exec_timeout)

    def _exec(self, cmd: str, timeout: float) -> ExecResult:
        if self._client is None:
            raise TargetUnreachable("not connected")
        transport = self._client.get_transport()
        chan = transport.open_session()
        chan.settimeout(0.5)
        chan.exec_command(cmd)
        deadline = time.monotonic() + timeout
        out: list[bytes] = []
        err: list[bytes] = []
        timed_out = False
        while True:
            if chan.recv_ready():
                out.append(chan.recv(65536))
            if chan.recv_stderr_ready():
                err.append(chan.recv_stderr(65536))
            if chan.exit_status_ready():
                while chan.recv_ready():
                    out.append(chan.recv(65536))
                while chan.recv_stderr_ready():
                    err.append(chan.recv_stderr(65536))
                break
            if time.monotonic() > deadline:
                timed_out = True
                break
            time.sleep(0.02)
        rc = -1 if timed_out else chan.recv_exit_status()
        try:
            chan.close()
        except Exception:  # noqa: BLE001
            pass
        return ExecResult(
            cmd=cmd,
            stdout=b"".join(out).decode("utf-8", "replace"),
            stderr=b"".join(err).decode("utf-8", "replace"),
            exit_code=rc,
            timed_out=timed_out,
        )

    # ── cached helpers ───────────────────────────────────────────────────
    def exists(self, path: str) -> bool:
        return self.run(f"test -e {shlex.quote(path)}").ok

    def cat(self, path: str) -> str | None:
        if "os_release" not in self._cache:
            self._cache["os_release"] = {}
        r = self.run(f"cat {shlex.quote(path)} 2>/dev/null")
        return r.stdout if r.ok else None

    def os_release(self) -> dict:
        if not self._cache.get("_osr_parsed"):
            text = self.cat("/etc/os-release") or ""
            fields: dict[str, str] = {}
            for line in text.splitlines():
                if "=" in line:
                    k, _, v = line.partition("=")
                    fields[k.strip()] = v.strip().strip('"')
            self._cache["_osr_parsed"] = fields
        return self._cache["_osr_parsed"]

    def model(self) -> str:
        if "model" not in self._cache:
            r = self.run(
                "cat /proc/device-tree/model 2>/dev/null | tr -d '\\0'")
            self._cache["model"] = r.stdout.strip() if r.ok else ""
        return self._cache["model"]

    def machine(self) -> str:
        """Map the device-tree model to a Yocto MACHINE name (best effort)."""
        if "machine" not in self._cache:
            m = self.model().lower()
            if "compute module 5" in m or "cm5" in m:
                self._cache["machine"] = "raspberrypi-cm5"
            elif "compute module 4" in m or "cm4" in m:
                self._cache["machine"] = "raspberrypi-cm4"
            elif "raspberry pi 5" in m:
                self._cache["machine"] = "raspberrypi5"
            elif "raspberry pi 4" in m:
                self._cache["machine"] = "raspberrypi4-64"
            elif "raspberry pi 3" in m:
                self._cache["machine"] = "raspberrypi3-64"
            elif m:
                self._cache["machine"] = "raspberrypi-other"
            else:
                self._cache["machine"] = "unknown"
        return self._cache["machine"]
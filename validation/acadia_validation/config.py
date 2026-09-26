"""Target configuration with CLI > env > default precedence."""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass
class TargetConfig:
    """How to reach and authenticate to the booted Acadia device."""

    host: str = ""
    port: int = 22
    user: str = "rpi"
    password: str | None = None
    key_file: str | None = None
    connect_timeout: float = 15.0
    exec_timeout: float = 60.0
    # CI mode: SKIP counts as failure (bench must prove everything)
    strict: bool = False
    # Deliberate bench deviation: password SSH enabled on the image
    allow_password_ssh: bool = False

    @staticmethod
    def from_env() -> dict:
        """Environment fallbacks so `make validate` can stay terse."""
        return {
            "host": os.environ.get("VALIDATION_HOST", ""),
            "user": os.environ.get("VALIDATION_USER", "rpi"),
            "port": int(os.environ.get("VALIDATION_PORT", "22")),
            "password": os.environ.get("VALIDATION_PASSWORD") or None,
            "key_file": os.environ.get("VALIDATION_KEY") or None,
        }
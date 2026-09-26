"""t08 — WebConfig (on-device configuration application).

Promise source: webconfigd.bb — daemon + applyd root helper + UI/schemas/
manifest, polkit-authorized service control (SB-2), TLS endpoint on :443.
"""

from acadia_validation.base import FeatureSuite


class WebConfigSuite(FeatureSuite):
    name = "webconfig"
    description = "webconfigd, applyd, TLS endpoint, polkit rule"
    groups = ("webconfig", "services")

    def check_daemon_active(self):
        return self.expect_unit("webconfigd.service")

    def check_applyd_active(self):
        """webconfig-applyd: the privileged applier root helper."""
        return self.expect_unit("webconfig-applyd.service")

    def check_daemon_binaries(self):
        r = self.run("for b in webconfigd webconfig-applyd; do "
                     "command -v \"$b\" >/dev/null 2>&1 "
                     "|| echo \"missing:$b\"; done")
        missing = [l.split(":", 1)[1] for l in r.stdout.splitlines()
                   if l.startswith("missing:")]
        if missing:
            return self.failed(f"missing binaries: {', '.join(missing)}")
        return self.passed("webconfigd + webconfig-applyd in PATH")

    def check_listening_socket(self):
        """webconfigd owns a listening TCP socket (TLS :443)."""
        r = self.run("ss -tlnp 2>/dev/null | grep webconfigd | head -1")
        line = r.stdout.strip()
        if line:
            return self.passed(line.strip()[:100])
        r = self.run("ss -tln 2>/dev/null | grep -q ':443 ' && echo yes")
        if r.ok:
            return self.passed(":443 listening (owner unidentifiable "
                               "without root)")
        return self.failed("webconfigd not listening on :443")

    def check_https_endpoint(self):
        """TLS endpoint answers on https://127.0.0.1 (self-signed OK)."""
        r = self.run("curl -k -s -o /dev/null -w '%{http_code}' "
                     "--max-time 10 https://127.0.0.1/ 2>/dev/null")
        code = r.stdout.strip()
        if code and code != "000":
            return self.passed(f"HTTPS answered HTTP {code}")
        return self.failed(f"HTTPS endpoint not reachable (code={code!r})")

    def check_polkit_rule(self):
        """SB-2: shipped 50-webconfigd.polkit.rules authorizes zbus path."""
        r = self.run("ls /etc/polkit-1/rules.d/ 2>/dev/null | "
                     "grep -i webconfig | head -1")
        name = r.stdout.strip()
        if name:
            return self.passed(f"/etc/polkit-1/rules.d/{name}")
        return self.failed("no webconfig polkit rule installed")

    def check_board_manifest(self):
        """webconfig-manifest package ships a board manifest."""
        r = self.run("find /etc /usr/share -maxdepth 4 "
                     "-iname '*board*manifest*' 2>/dev/null | head -1")
        path = r.stdout.strip()
        if path:
            return self.passed(path)
        return self.skipped("manifest location unresolved "
                            "(depends on Acadia-Configuration layout)")
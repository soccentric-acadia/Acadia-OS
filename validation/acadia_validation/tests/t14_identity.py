"""t14 — Device identity & provisioning.

Promises: acadia-device-identity (sbindir tool + unit), factory provisioning
(T-P09: /pst/factory/identity/identity.yaml write-once + claim-code mirror),
acadia-boot-integrity (read-only status reporter), acadia-hal, acadia-client
(IV&V gRPC agent), optional acadia-hq-trust.
"""

from acadia_validation.base import FeatureSuite


class IdentitySuite(FeatureSuite):
    name = "identity"
    description = "Device identity, factory provisioning, boot integrity"
    groups = ("core", "identity")

    def check_device_identity_unit(self):
        return self.expect_unit("acadia-device-identity.service",
                                allow_inactive=True)

    def check_identity_tool(self):
        """${sbindir}/acadia-device-identity (T-P11 chain)."""
        r = self.run("command -v acadia-device-identity || "
                     "test -x /usr/sbin/acadia-device-identity && echo "
                     "/usr/sbin/acadia-device-identity")
        if r.ok and r.stdout.strip():
            return self.passed(r.stdout.strip().splitlines()[0])
        return self.failed("acadia-device-identity tool missing")

    def check_factory_identity_record(self):
        """T-P09: identity.yaml + .secret written once at provisioning."""
        if not self.is_ab_board():
            return self.skipped("/pst store is rpi5/cm5-only")
        if not self.exists("/pst/factory/identity/identity.yaml"):
            return self.warned("device not factory-provisioned yet "
                               "(write-once record absent)")
        secret = self.run("test -e /pst/factory/identity/.secret && echo yes")
        if secret.ok:
            return self.passed("identity.yaml + .secret present")
        return self.warned("identity.yaml present but .secret missing")

    def check_claim_code_mirror(self):
        """claim code mirrored to /pst/webconfig/claim-code."""
        if not self.is_ab_board():
            return self.skipped("/pst store is rpi5/cm5-only")
        if self.exists("/pst/webconfig/claim-code"):
            return self.passed("/pst/webconfig/claim-code present")
        return self.warned("no claim-code mirror (device unprovisioned?)")

    def check_boot_integrity_tool(self):
        """acadia-boot-integrity: read-only secure-boot/dm-verity report."""
        r = self.run("command -v acadia-boot-integrity || "
                     "test -x /usr/sbin/acadia-boot-integrity && echo found")
        if not r.ok:
            return self.failed("acadia-boot-integrity missing")
        run = self.run("acadia-boot-integrity 2>&1 | head -2", timeout=30)
        if run.ok or run.stdout.strip():
            first = run.stdout.strip().splitlines()[0] if run.stdout.strip() \
                else "(empty output)"
            return self.passed(f"ran read-only: {first[:100]}")
        return self.failed(f"tool present but errored: "
                           f"{(run.stderr.strip() or run.stdout.strip())[:120]}")

    def check_acadia_client_active(self):
        """OS-028: acadia-client (IV&V gRPC agent) in the image."""
        st = self.unit_state("acadia-client.service")
        state = st.get("ActiveState", "missing")
        if state == "active":
            return self.passed("acadia-client active")
        if state == "activating":
            return self.warned("acadia-client activating "
                               "(IV&V server unreachable?)")
        return self.failed(f"acadia-client {state}")

    def check_acadia_hal(self):
        """Acadia-HAL library ships in the image (acadia-hal recipe)."""
        count = self.count_lines(
            "ldconfig -p 2>/dev/null | grep -ic acadia; "
            "find /usr/lib -maxdepth 1 -iname '*acadia*' 2>/dev/null "
            "| grep -c .")
        if count > 0:
            return self.passed(f"{count} acadia library entries found")
        return self.warned("no acadia HAL libraries visible via ldconfig/find "
                           "(verify acadia-hal packaging)")

    def check_hq_trust_optional(self):
        """acadia-hq-trust: empty unless ACADIA_HQ_* build vars are set."""
        r = self.run("find /etc -maxdepth 3 -iname '*hq*' 2>/dev/null | head -1")
        path = r.stdout.strip()
        if path:
            return self.passed(path)
        return self.skipped("optional package (no CA/config key provisioned "
                            "at build time)")
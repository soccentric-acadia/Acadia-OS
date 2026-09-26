"""t06 — Security & hardening.

Promises: acadia-hardening.conf (PasswordAuthentication no, PermitRootLogin
no, AllowUsers rpi operator), default-deny nftables (F01), acadia-sudoers
drop-in, locked-until-provisioned accounts (T-P11).
"""

from acadia_validation.base import FeatureSuite


class SecuritySuite(FeatureSuite):
    name = "security"
    description = "SSH policy, nftables firewall, sudoers, account state"
    groups = ("core", "security")

    def check_sshd_effective_policy(self):
        """sshd -T effective values vs the shipped hardening."""
        r = self.run_priv("/usr/sbin/sshd -T 2>/dev/null")
        if r is None or not r.ok:
            # Fall back to the shipped config drop-in file evidence.
            conf = self.conn.cat("/etc/ssh/sshd_config.d/acadia-hardening.conf")
            if conf is None:
                return self.skipped("no sudo for sshd -T and no readable "
                                    "sshd drop-in")
            text = conf.lower()
            pw = "passwordauthentication yes" in text
            root = "permitrootlogin yes" in text
            if root:
                return self.failed("config permits root login "
                                   "(file-evidence mode)")
            if pw:
                if self.conn.cfg.allow_password_ssh:
                    return self.warned("password SSH on (file-evidence, "
                                       "deliberate bench mode)")
                return self.failed("config enables password auth "
                                   "(pass --allow-password-ssh if "
                                   "deliberate)")
            return self.passed("hardening.conf verified "
                               "(file-evidence, no sudo for sshd -T)")

        eff = {}
        password_note = ""
        for line in r.stdout.splitlines():
            k, _, v = line.partition(" ")
            if k in ("passwordauthentication", "permitrootlogin",
                     "allowusers"):
                eff[k] = v.strip()
        problems = []
        if eff.get("permitrootlogin") != "no":
            problems.append(f"permitrootlogin={eff.get('permitrootlogin')!r} "
                            "(must be no)")
        if eff.get("passwordauthentication") != "no":
            if self.conn.cfg.allow_password_ssh:
                password_note = "password auth on (deliberate bench mode)"
            else:
                problems.append(
                    "passwordauthentication=yes (pass "
                    "--allow-password-ssh if deliberate)")
        if "rpi" not in eff.get("allowusers", ""):
            problems.append(f"allowusers missing rpi: "
                            f"{eff.get('allowusers', '')!r}")
        if problems:
            return self.failed("; ".join(problems))
        note = password_note if self.conn.cfg.allow_password_ssh else ""
        return self.passed(f"root=no, allowusers={eff.get('allowusers', '')}"
                           + (f"; {note}" if note else ""))

    def check_nftables_ruleset(self):
        """F01: default-deny nftables firewall (acadia-firewall.service)."""
        r = self.run_priv("nft list ruleset 2>/dev/null")
        if r is not None:
            ruleset = r.stdout
            if "chain" in ruleset and "policy drop" in ruleset.lower():
                chains = ruleset.count("chain ")
                return self.passed(f"runtime ruleset present "
                                   f"({chains} chains, drop policy)")
            if ruleset.strip():
                return self.warned("ruleset present but no drop policy "
                                   "line found")
            return self.failed("nft ruleset empty (firewall not applied)")
        # No sudo: verify the shipped ruleset file as evidence instead.
        r = self.run("find /usr/lib/acadia-hardening /etc -maxdepth 3 "
                     "-name '*acadia*default*nft*' -o -maxdepth 3 "
                     "-name 'acadia-default.nft' 2>/dev/null | head -1")
        if r.stdout.strip():
            return self.passed(f"shipped ruleset file: {r.stdout.strip()} "
                               "(runtime check needs sudo)")
        return self.skipped("no sudo; shipped nft ruleset not found")

    def check_sudoers_dropin(self):
        """acadia-hardening ships /etc/sudoers.d drop-in."""
        r = self.run("ls /etc/sudoers.d/ 2>/dev/null | grep -i acadia || true")
        name = r.stdout.strip()
        if name:
            return self.passed(f"/etc/sudoers.d/{name.splitlines()[0]}")
        return self.failed("no acadia drop-in in /etc/sudoers.d")

    def check_operational_accounts(self):
        """rpi + operator exist, locked until first use (T-P11, OS-004)."""
        r = self.run("grep -E '^(rpi|operator):' /etc/passwd | cut -d: -f1")
        found = {l.strip() for l in r.stdout.splitlines() if l.strip()}
        problems = []
        for acct in ("rpi", "operator"):
            if acct not in found:
                problems.append(f"{acct} missing from /etc/passwd")
        if problems:
            return self.failed("; ".join(problems))
        states = {}
        for acct in ("rpi", "operator"):
            s = self.run(f"passwd -S {acct} 2>/dev/null | awk '{{print $2}}'")
            states[acct] = s.stdout.strip() or "?"
        locked = [a for a, v in states.items() if v == "L"]
        if len(locked) == 2:
            return self.passed("rpi + operator present, both locked "
                               "until provisioned")
        return self.warned(f"accounts present; lock state: {states} "
                           "(provisioned?)")

    def check_systemd_config_dropins(self):
        """journald-acadia.conf + timesyncd-acadia.conf (systemd bbappend)."""
        r = self.run("find /etc/systemd -name '*acadia*' 2>/dev/null | head")
        found = [l.strip() for l in r.stdout.splitlines() if l.strip()]
        names = {f.split("/")[-1] for f in found}
        missing = ({"journald-acadia.conf", "timesyncd-acadia.conf"}
                   - names)
        if not missing:
            return self.passed(f"both acadia drop-ins present: {sorted(names)}")
        return self.failed(f"missing drop-ins: {sorted(missing)}")
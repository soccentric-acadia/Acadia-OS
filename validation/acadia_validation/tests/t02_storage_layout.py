"""t02 — Storage & A/B layout.

Promises: sdimage-rpi5.wks (boot FAT32, rootfs-a/rootfs-b ext4, /pst p4,
/home p5), acadia-pst-init (pst.mount), rpi5-home-init, acadia-data-init
(/home/acadia + var-lib-acadia.mount bind), expand-rootfs only on
single-partition boards.
"""

from acadia_validation.base import FeatureSuite


class StorageLayoutSuite(FeatureSuite):
    name = "storage-layout"
    description = "A/B slots, /pst, /home persistence, promised mounts"
    groups = ("core", "storage")

    def _findmnt(self, target: str) -> str:
        r = self.run(f"findmnt -n -o SOURCE,FSTYPE -- {target} 2>/dev/null")
        return r.stdout.strip()

    def check_boot_partition(self):
        """FAT32 boot partition mounted at /boot (rpi machine conf)."""
        if not self.machine().startswith("raspberrypi"):
            return self.skipped(f"not a raspberrypi machine")
        mnt = self._findmnt("/boot")
        if not mnt:
            return self.failed("/boot is not mounted")
        if "vfat" not in mnt:
            return self.failed(f"/boot not vfat: {mnt}")
        return self.passed(f"{mnt}")

    def check_home_persistent(self):
        """/home is its own ext4 partition, writable (rpi5-home-init)."""
        mnt = self._findmnt("/home")
        if not mnt:
            return self.failed("/home is not mounted")
        root_src = self.run("findmnt -n -o SOURCE / 2>/dev/null").stdout.strip()
        if root_src and mnt.split()[0] == root_src.split()[0]:
            return self.failed("/home on the rootfs source "
                               "(persistence promise broken)")
        r = self.run("touch /home/.acadia-val && rm /home/.acadia-val")
        if not r.ok:
            return self.failed(f"/home not writable: {r.stderr.strip()}")
        return self.passed(f"{mnt} (writable)")

    def check_pst_partition(self):
        """task 003 / T-P01: p4 LABEL=pst mounted at /pst."""
        if not self.is_ab_board():
            return self.skipped("A/B layout (incl. /pst) is rpi5/cm5-only")
        mnt = self._findmnt("/pst")
        if not mnt:
            return self.failed("/pst not mounted (sdimage-rpi5.wks p4 "
                               "LABEL=pst promise)")
        return self.passed(mnt)

    def check_ab_slots(self):
        """Dual ext4 rootfs slots (rootfs-a active, rootfs-b present)."""
        if not self.is_ab_board():
            return self.skipped("A/B layout is rpi5/cm5-only")
        root_src = self.run(
            "findmnt -n -o SOURCE / 2>/dev/null").stdout.strip()
        if not root_src:
            return self.failed("cannot determine rootfs source")
        part = root_src.rsplit("p", 1)
        sibling = f"{part[0]}p{int(part[1]) + 1}"
        r = self.run(f"test -b {sibling} && lsblk -n -o FSTYPE "
                     f"{sibling} 2>/dev/null | grep -q ext4")
        if r.ok:
            return self.passed(f"active slot {root_src}, "
                               f"inactive slot {sibling} (ext4)")
        return self.failed(f"no ext4 sibling slot next to {root_src} "
                           f"(A/B WKS promise)")

    def check_var_lib_acadia_bind(self):
        """issue #114: /var/lib/acadia binds /home/acadia (survives OTA)."""
        if not self.is_ab_board():
            return self.skipped("A/B layout is rpi5/cm5-only")
        mnt = self._findmnt("/var/lib/acadia")
        if not mnt:
            return self.failed("/var/lib/acadia not a mount "
                               "(var-lib-acadia.mount promise)")
        return self.passed(mnt)

    def check_data_dirs(self):
        """acadia-data-init creates /home/acadia; /pst store present."""
        checks = []
        if not self.exists("/home/acadia"):
            checks.append("/home/acadia missing (acadia-data-init)")
        if self.is_ab_board() and not self.exists("/pst"):
            checks.append("/pst missing")
        if checks:
            return self.failed("; ".join(checks))
        return self.passed("/home/acadia (+ /pst) present")

    def check_expand_rootfs_policy(self):
        """expand-rootfs ships only on single-partition boards; removed on
        the fixed-size A/B WKS boards (acadia-image.bb)."""
        unit = "/etc/systemd/system/expand-rootfs.service"
        if self.is_ab_board():
            if self.exists(unit):
                return self.failed("expand-rootfs installed on A/B board "
                                   "(must be removed there)")
            return self.passed("correctly absent on A/B board")
        st = self.unit_state("expand-rootfs.service")
        if not st:
            return self.failed("expand-rootfs unit missing "
                               "(needed on single-partition boards)")
        return self.expect_unit("expand-rootfs.service",
                                allow_inactive=True)
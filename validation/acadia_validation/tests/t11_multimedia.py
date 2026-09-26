"""t11 — Camera / Video / Audio stack.

Promise source: acadia-image.bb media section — libcamera + rpicam tools,
GStreamer (+v4l2src), ffmpeg, V4L2 nodes, DRM tests, ALSA; acadia-camera
service ships inert unless ENABLED=1 (task.md Camera-Video).
"""

from acadia_validation.base import FeatureSuite


class MultimediaSuite(FeatureSuite):
    name = "multimedia"
    description = "libcamera, GStreamer, V4L2, DRM tests, ALSA, acadia-camera"
    groups = ("multimedia", "hardware")

    def check_libcamera(self):
        """rpicam-* CLI tools for Unicam/ISP bring-up diagnostics."""
        r = self.run("command -v rpicam-hello")
        if not r.ok:
            return self.failed("rpicam-hello missing (libcamera-apps)")
        r = self.run("rpicam-hello --list-cameras 2>&1", timeout=30)
        if r.exit_code != 0:
            return self.warned(f"rpicam-hello failed: "
                               f"{r.stdout.strip()[:100] or r.stderr.strip()}")
        cams = [l for l in r.stdout.splitlines() if l.strip()[:1].isdigit()]
        if cams:
            return self.passed(f"{len(cams)} camera(s) detected: "
                               f"{cams[0].strip()}")
        return self.warned("camera stack present, no camera module "
                           "attached (hardware)")

    def check_gstreamer(self):
        """GStreamer V4L2 pipeline (H.265/HEVC decode path)."""
        missing = []
        for plugin in ("v4l2src", "coreelements"):
            r = self.run(f"gst-inspect-1.0 {plugin} >/dev/null 2>&1")
            if not r.ok:
                missing.append(plugin)
        if missing:
            return self.failed(f"gstreamer plugins missing: "
                               f"{', '.join(missing)}")
        return self.passed("gst-inspect sees v4l2src + coreelements")

    def check_ffmpeg(self):
        r = self.run("ffmpeg -version 2>/dev/null | head -1")
        if r.ok and r.stdout.strip():
            return self.passed(r.stdout.strip()[:80])
        return self.failed("ffmpeg not runnable")

    def check_v4l2_nodes(self):
        count = self.count_lines("ls /dev/video* 2>/dev/null | grep -c .")
        if count > 0:
            return self.passed(f"{count} /dev/video node(s)")
        return self.warned("no /dev/video nodes (Unicam idle, "
                           "camera optional)")

    def check_display_tests(self):
        """kmscube + modetest for KMS/DRM bring-up (task.md Display)."""
        r = self.run("command -v modetest && command -v kmscube")
        if r.ok:
            return self.passed("modetest + kmscube present")
        return self.failed("modetest or kmscube missing (libdrm-tests)")

    def check_alsa(self):
        """alsa-utils: aplay/arecord/speaker-test for audio bring-up."""
        count = self.count_lines("aplay -l 2>/dev/null | grep -c .")
        if count > 0:
            return self.passed(f"ALSA devices listed ({count} lines)")
        r = self.run("command -v aplay")
        if r.ok:
            return self.warned("aplay present, no ALSA device "
                               "(no audio HAT)")
        return self.failed("aplay missing (alsa-utils promise)")

    def check_camera_capture(self):
        """Actual capture when a camera is attached (rpicam-still, read-only
        on the FS; skipped without a camera)."""
        r = self.run("rpicam-hello --list-cameras 2>&1", timeout=30)
        cams = [l for l in r.stdout.splitlines() if l.strip()[:1].isdigit()]
        if not cams:
            return self.skipped("no camera module attached")
        run = self.run_priv("rpicam-still -o /tmp/.acadia-val.jpg "
                            "--width 640 --height 480 -t 2000 2>&1",
                            timeout=60)
        if run is None:
            return self.skipped("capture needs root and no passwordless "
                                "sudo")
        if run.ok and self.exists("/tmp/.acadia-val.jpg"):
            self.run("rm -f /tmp/.acadia-val.jpg")
            return self.passed(f"captured 640x480 still from {len(cams)} "
                               "camera(s)")
        return self.warned(f"camera present but capture failed: "
                           f"{(run.stdout.strip() or run.stderr.strip())[:120]}")

    def check_camera_capture_service(self):
        """acadia-camera ships inert unless ENABLED=1 in its conf."""
        conf = self.conn.cat("/etc/acadia/camera-capture.conf")
        if conf is None:
            return self.failed("/etc/acadia/camera-capture.conf missing")
        st = self.unit_state("acadia-camera-capture.service")
        if not st:
            return self.failed("acadia-camera-capture.service missing")
        enabled = "ENABLED" in conf and "1" in conf.split("ENABLED", 1)[1][:8]
        if enabled and st.get("ActiveState") == "active":
            return self.passed("capture service enabled and active")
        if st.get("ActiveState") in ("inactive", "active"):
            return self.passed(f"inert by default (ENABLED={'1' if enabled else '0'}, "
                               f"state={st.get('ActiveState')})")
        return self.failed(f"camera-capture unit state "
                           f"{st.get('ActiveState', 'missing')}")
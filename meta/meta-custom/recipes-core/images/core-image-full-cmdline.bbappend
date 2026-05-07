# Pull expand-rootfs into every image built from core-image-base.
IMAGE_INSTALL:append = " expand-rootfs"

# Connectivity — Ethernet DHCP, WiFi (wpa_supplicant), Bluetooth
# linux-firmware-rpidistro is pulled in by meta-raspberrypi MACHINE_EXTRA_RRECOMMENDS
# but we declare the tools explicitly for clarity.
IMAGE_INSTALL:append = " \
    rpi5-connectivity \
    wpa-supplicant \
    iw \
    rfkill \
    bluez5 \
    bluez5-dev \
"

# gRPC + Protocol Buffers (C++ runtime, compiler plugin, and Python bindings)
IMAGE_INSTALL:append = " \
    protobuf \
    protobuf-compiler \
    protobuf-lite \
    grpc \
    python3-grpcio \
    python3-protobuf \
    sudo \
"

# Add local user 'rpi' with password 'rpi' and sudo access
inherit extrausers

EXTRA_USERS_PARAMS = "\
    useradd -m -s /bin/bash -G sudo rpi; \
    usermod -p '\$6\$8.kfghMSYkTHsFqs\$fKQIEp.xMjitUYt9yXjEZBUvKqUOQvxekn5.9hWP9ewiLFSI0LQi5OpaDNfSqh4OU.tzN7co7olMAYg53/kCP0' rpi; \
"

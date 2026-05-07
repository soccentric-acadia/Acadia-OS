FROM ghcr.io/siemens/kas/kas:latest

# Install bmap-tools (efficient SD card flashing) and a few extras
# that may be handy inside the build container.
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bmap-tools \
        fdisk \
        parted \
        file \
    && rm -rf /var/lib/apt/lists/*

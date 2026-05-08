# --- Configuration -----------------------------------------------------------
KAS_IMAGE        ?= rpi5-kas:latest
# Pin to a specific kas release tag — https://github.com/siemens/kas/releases
KAS_VERSION      ?= 4.5
# Yocto image recipe built by build/sdk/esdk/rebuild-image targets
IMAGE_TARGET     ?= core-image-full-cmdline
SWU_VERSION      ?= $(shell date +%Y%m%d%H%M)

# Select target board — must match a file in kas/<BOARD>.yaml
# Examples: rpi5 rpi4-64 rpi4 rpi3-64 rpi3 rpi2
#           rpi0-2w-64 rpi0-2w rpi0-wifi rpi0 rpi1
#           rpi-armv7 rpi-armv8 cm1 cm3 cm5
BOARD            ?= rpi5
KAS_CONFIG       := kas/boards/$(BOARD).yaml

# Derive MACHINE automatically from the selected kas yaml
MACHINE          := $(shell grep '^machine:' $(KAS_CONFIG) 2>/dev/null | awk '{print $$2}')

BUILD_DIR        ?= $(CURDIR)/build
DL_DIR           ?= $(CURDIR)/downloads
SSTATE_DIR       ?= $(CURDIR)/sstate-cache

# kas-container script — downloaded once into the project root
KAS_CONTAINER    := $(CURDIR)/kas-container
KAS_CONTAINER_URL = https://raw.githubusercontent.com/siemens/kas/refs/tags/$(KAS_VERSION)/kas-container

# --- kas-container invocation ------------------------------------------------
# All KAS operations go through kas-container which handles Docker volume mounts,
# UID/GID remapping, and build-dir env vars automatically.
KAS_ENV = \
	KAS_CONTAINER_IMAGE=$(KAS_IMAGE) \
	KAS_BUILD_DIR=$(BUILD_DIR) \
	DL_DIR=$(DL_DIR) \
	SSTATE_DIR=$(SSTATE_DIR)

KAS_RUN = $(KAS_ENV) $(KAS_CONTAINER)

# --- Targets -----------------------------------------------------------------
.PHONY: all build rebuild-image image ensure-image kas-container-script shell flash sdk esdk swu clean clean-all completion help

all: build

## Download the kas-container helper script (once)
kas-container-script:
	@if [ ! -f $(KAS_CONTAINER) ]; then \
	    echo "Downloading kas-container script..."; \
	    curl -fsSL $(KAS_CONTAINER_URL) -o $(KAS_CONTAINER); \
	    chmod +x $(KAS_CONTAINER); \
	fi

## Build (or rebuild) the KAS Docker image
image:
	$(MAKE) -C docker \
	    IMAGE_NAME=$(firstword $(subst :, ,$(KAS_IMAGE))) \
	    IMAGE_TAG=$(lastword  $(subst :, ,$(KAS_IMAGE))) \
	    KAS_VERSION=$(KAS_VERSION)

## Ensure the KAS Docker image exists; build it only when absent (use 'make image' to force a rebuild)
ensure-image:
	@docker image inspect $(KAS_IMAGE) >/dev/null 2>&1 || $(MAKE) image

## Build the Yocto image for the selected BOARD
build: ensure-image kas-container-script
	mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) build $(KAS_CONFIG)

## Clean sstate for the image recipe then rebuild  (use after adding packages)
rebuild-image: ensure-image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c cleansstate $(IMAGE_TARGET)"
	$(KAS_RUN) build $(KAS_CONFIG)

## Interactive shell inside the build container
shell: ensure-image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG)

## Build the standard SDK (cross-toolchain + sysroot installer)
sdk: ensure-image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk $(IMAGE_TARGET)"

## Build the extensible SDK (eSDK — includes devtool and full layer checkout)
esdk: ensure-image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk_ext $(IMAGE_TARGET)"

## Build a .swu OTA update package from the latest rootfs.ext4 image
## Usage: make swu   or   make swu SWU_VERSION=1.2.3
swu: build
	$(eval ROOTFS := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -name "core-image-full-cmdline-$(MACHINE)*.rootfs.ext4" 2>/dev/null | sort -V | tail -1))
	@test -n "$(ROOTFS)" || \
	    { echo "ERROR: No .rootfs.ext4 found. Ensure 'ext4' is in IMAGE_FSTYPES."; exit 1; }
	@echo "Packaging OTA update from: $(ROOTFS)"
	@mkdir -p $(BUILD_DIR)/swu
	@gzip -kfc "$(ROOTFS)" > "$(BUILD_DIR)/swu/rootfs.ext4.gz"
	@sed "s|@@VERSION@@|$(SWU_VERSION)|" \
	    meta/meta-custom/swupdate/sw-description \
	    > "$(BUILD_DIR)/swu/sw-description"
	@cp meta/meta-custom/swupdate/pre-install.sh  "$(BUILD_DIR)/swu/"
	@cp meta/meta-custom/swupdate/post-install.sh "$(BUILD_DIR)/swu/"
	@cd "$(BUILD_DIR)/swu" && \
	    printf 'sw-description\npre-install.sh\npost-install.sh\nrootfs.ext4.gz\n' | \
	    cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"
	@echo "OTA package: $(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"

## Flash to SD card.  Usage: make flash DEVICE=/dev/sdX
flash:
ifndef DEVICE
	$(error DEVICE is not set -- example: make flash DEVICE=/dev/sdb)
endif
	@test -b "$(DEVICE)" || \
	    { echo "ERROR: '$(DEVICE)' is not a block device."; exit 1; }
	$(eval WIC := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) -name "*.wic.bz2" | sort -V | tail -1))
	@test -n "$(WIC)" || { echo "ERROR: no .wic.bz2 in $(BUILD_DIR)/tmp/deploy/images/$(MACHINE)"; exit 1; }
	@echo "Flashing $(WIC) to $(DEVICE)"
	bmaptool copy --bmap "$(WIC:.bz2=.bmap)" "$(WIC)" "$(DEVICE)"

## Delete the build directory
clean:
	rm -rf $(BUILD_DIR)

## Delete build directory, downloads, and sstate cache
clean-all: clean
	rm -rf $(DL_DIR) $(SSTATE_DIR)

## Install bash tab-completion (sources rpi-make-completion.bash from ~/.bashrc)
completion:
	@RCFILE="$$HOME/.bashrc"; \
	 LINE="source \"$(CURDIR)/rpi-make-completion.bash\""; \
	 if grep -qF "$$LINE" "$$RCFILE" 2>/dev/null; then \
	     echo "Completion already enabled in $$RCFILE"; \
	 else \
	     printf '\n# rpi Makefile tab-completion\n%s\n' "$$LINE" >> "$$RCFILE"; \
	     echo "Added to $$RCFILE — run: source $$RCFILE"; \
	 fi

help:
	@printf "\nUsage: make [target] [VAR=value ...]\n"
	@printf "\nTargets:\n"
	@printf "  %-16s %s\n" "build"          "Build Docker image + Yocto image (default)"
	@printf "  %-16s %s\n" "rebuild-image"  "cleansstate image recipe then rebuild (after adding packages)"
	@printf "  %-16s %s\n" "image"          "Build (or rebuild) the KAS Docker image"
	@printf "  %-16s %s\n" "ensure-image"   "Build the KAS Docker image only if absent"
	@printf "  %-16s %s\n" "shell"          "Interactive kas shell in the build container"
	@printf "  %-16s %s\n" "sdk"            "Build standard SDK (cross-toolchain + sysroot)"
	@printf "  %-16s %s\n" "esdk"           "Build extensible SDK (devtool + layer checkout)"
	@printf "  %-16s %s\n" "flash"          "Flash SD card  -- requires DEVICE=/dev/sdX"
	@printf "  %-16s %s\n" "swu"            "Build .swu OTA package  [SWU_VERSION=YYYYMMDDHHMM]"
	@printf "  %-16s %s\n" "clean"      "Remove build/"
	@printf "  %-16s %s\n" "clean-all"  "Remove build/, downloads/, sstate-cache/"
	@printf "  %-16s %s\n" "completion" "Install bash tab-completion into ~/.bashrc"
	@printf "\nVariables:\n"
	@printf "  %-22s %s\n" "BOARD"         "Target board kas config (default: rpi5)"
	@printf "  %-22s %s\n" ""              "Boards: rpi5 rpi4-64 rpi4 rpi3-64 rpi3 rpi2"
	@printf "  %-22s %s\n" ""              "        rpi0-2w-64 rpi0-2w rpi0-wifi rpi0 rpi1"
	@printf "  %-22s %s\n" ""              "        rpi-armv7 rpi-armv8 cm1 cm3 cm5"
	@printf "  %-22s %s\n" "KAS_IMAGE"     "Docker image  (default: rpi5-kas:latest)"
	@printf "  %-22s %s\n" "KAS_VERSION"   "kas release tag (default: 4.5) — sets script + Docker base"
	@printf "  %-22s %s\n" "IMAGE_TARGET"  "Yocto image recipe (default: core-image-full-cmdline)"
	@printf "  %-22s %s\n" "BUILD_DIR"     "Build output  (default: ./build)"
	@printf "  %-22s %s\n" "DL_DIR"        "Download cache (default: ./downloads)"
	@printf "  %-22s %s\n" "SSTATE_DIR"    "Sstate cache  (default: ./sstate-cache)"
	@printf "\n"

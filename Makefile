# =============================================================================
# RPi Yocto Build System
# =============================================================================

# --- Image names -------------------------------------------------------------
# Per-board Docker image tags so multiple boards can co-exist (issue #112).
# Default is rpi5 (matching the BOARD default below).  Override the image
# name with a Make variable for non-rpi5 boards, e.g.:
#   make sdk-image rpi4-64 SDK_IMAGE=rpi4-64-sdk:latest
# but the conventional pattern is to let the board drive the name:
#   KAS_IMAGE  = $(BOARD)-kas:latest
#   SDK_IMAGE  = $(BOARD)-sdk:latest
#   ESDK_IMAGE = $(BOARD)-esdk:latest
KAS_IMAGE        ?= $(BOARD)-kas:latest
SDK_IMAGE        ?= $(BOARD)-sdk:latest
ESDK_IMAGE       ?= $(BOARD)-esdk:latest

# Pin to a specific kas release — https://github.com/siemens/kas/releases
KAS_VERSION      ?= 4.5

# Yocto image recipe built by build / sdk / esdk / rebuild-image targets
IMAGE_TARGET     ?= acadia-image

# OTA package version.  If the user passes SWU_VERSION=… on the command
# line, use it verbatim; otherwise default to the same timestamp as
# DEPLOY_TS so the .swu filename and its deploy dir always match.
# `:=` (immediate) is intentional — it captures the value at parse
# time, so a single `make` invocation cannot re-evaluate it after
# sub-shells that touch the clock.  See issue #40.
SWU_VERSION      ?= $(DEPLOY_TS)

# --- Positional board argument -----------------------------------------------
# The board name is typed directly after the target — no BOARD= needed:
#   make image rpi5
#   make sdk   rpi4-64
#   make esdk  rpi3-64
#   make shell cm5
# This block MUST appear before the BOARD default and KAS_CONFIG / MACHINE
# definitions so those variables are derived from the correct board name.
_BOARD_TARGETS := image build rebuild-image sdk esdk sdk-image esdk-image shell swu flash

# `make image rpi5 SWU_VERSION=1.2.3` puts 'SWU_VERSION=1.2.3' in
# MAKECMDGOALS (it's a make-assignment, not an option).  Filter those
# out before testing for the board name — issue #64.  An assignment
# token is the only one that contains '='.
_NON_ASSIGN_GOALS := $(filter-out %=,$(_BOARD_TARGETS))

ifneq ($(filter $(_NON_ASSIGN_GOALS),$(firstword $(MAKECMDGOALS))),)
  _BOARD_ARG := $(word 2,$(MAKECMDGOALS))
  # If the user wrote `make image SWU_VERSION=1.2.3` (no board), the
  # second word is the assignment; skip — the default BOARD applies.
  ifneq ($(filter %=,$(_BOARD_ARG)),)
    _BOARD_ARG :=
  endif
  ifneq ($(_BOARD_ARG),)
    # Only apply when BOARD was not explicitly set on the command line
    ifeq ($(origin BOARD),undefined)
      BOARD := $(_BOARD_ARG)
    endif
    # Prevent make from treating the board name as a missing target
    $(eval $(_BOARD_ARG):;@true)
  endif
endif

# --- Board -------------------------------------------------------------------
# Select target board — must match a file in kas/boards/<BOARD>.yaml
# Boards: rpi5  rpi4-64  rpi4  rpi3-64  rpi3  rpi2
#         rpi0-2w-64  rpi0-2w  rpi0-wifi  rpi0  rpi1
#         rpi-armv7  rpi-armv8  cm1  cm3  cm5
BOARD            ?= rpi5
KAS_CONFIG       := kas/boards/$(BOARD).yaml

# Derive MACHINE automatically from the kas yaml
MACHINE          := $(shell grep '^machine:' $(KAS_CONFIG) 2>/dev/null | awk '{print $$2}')

# --- Per-board kernel/DTB filenames (issue #63) -----------------------------
# 'make swu' must copy the kernel and DTB into the .swu package so the
# OTA flow can update them — but the names differ by SoC:
#
#   SoC    Board             Kernel                  DTB
#   ----   ----------------  ---------------------   --------------------------------
#   2712   rpi5 / cm5        kernel_2712.img        bcm2712-rpi-5-b.dtb
#   2711   rpi4 / rpi4-64    kernel_2711.img        bcm2711-rpi-4-b.dtb
#   2711   cm4               kernel_2711.img        bcm2711-rpi-cm4-io.dtb
#   2710   rpi3 / rpi3-64    kernel_2710.img        bcm2710-rpi-3-b.dtb
#   2837   cm3               kernel.img             bcm2837-rpi-cm3.dtb
#   2835   cm1               kernel.img             bcm2835-rpi-cm.dtb
#   2708   rpi0 / rpi0-wifi  kernel.img             bcm2708-rpi-zero.dtb
#
# Boards NOT in the table (issue #111: rpi-armv7, rpi-armv8) fail
# closed with a clear error rather than silently building a broken
# .swu.  Override on the command line for these boards once you
# have verified the kernel/DTB filename in the deploy dir:
#   make swu rpi-armv7 SWU_KERNEL=... SWU_DTB=...
ifeq ($(BOARD),rpi5)
  SWU_KERNEL ?= kernel_2712.img
  SWU_DTB    ?= bcm2712-rpi-5-b.dtb
else ifeq ($(BOARD),cm5)
  SWU_KERNEL ?= kernel_2712.img
  SWU_DTB    ?= bcm2712-rpi-5-b.dtb
else ifeq ($(BOARD),cm4)
  SWU_KERNEL ?= kernel_2711.img
  SWU_DTB    ?= bcm2711-rpi-cm4-io.dtb
else ifneq ($(filter rpi4%,$(BOARD)),)
  SWU_KERNEL ?= kernel_2711.img
  SWU_DTB    ?= bcm2711-rpi-4-b.dtb
else ifneq ($(filter rpi3%,$(BOARD)),)
  SWU_KERNEL ?= kernel_2710.img
  SWU_DTB    ?= bcm2710-rpi-3-b.dtb
else ifeq ($(BOARD),cm3)
  SWU_KERNEL ?= kernel.img
  SWU_DTB    ?= bcm2837-rpi-cm3.dtb
else ifeq ($(BOARD),cm1)
  SWU_KERNEL ?= kernel.img
  SWU_DTB    ?= bcm2835-rpi-cm.dtb
else ifneq ($(filter rpi0%,$(BOARD)),)
  SWU_KERNEL ?= kernel.img
  SWU_DTB    ?= bcm2708-rpi-zero.dtb
else ifeq ($(BOARD),rpi2)
  SWU_KERNEL ?= kernel7.img
  SWU_DTB    ?= bcm2709-rpi-2-b.dtb
else ifeq ($(BOARD),rpi1)
  SWU_KERNEL ?= kernel.img
  SWU_DTB    ?= bcm2708-rpi-b.dtb
endif

# --- Directories -------------------------------------------------------------
BUILD_DIR        ?= $(CURDIR)/build
CACHE_DIR        ?= $(CURDIR)/cache
DL_DIR           ?= $(CACHE_DIR)/downloads
SSTATE_DIR       ?= $(CACHE_DIR)/sstate-cache
DEPLOY_DIR       ?= $(CURDIR)/deploy

# Single timestamp for the entire invocation — keeps all artifacts in the same
# snapshot directory and is passed explicitly to recursive make calls.
DEPLOY_TS        := $(shell date +%Y%m%d_%H%M%S)

# SDK / eSDK install paths inside the Docker containers
SDK_INSTALL_DIR  ?= /opt/poky/sdk
ESDK_INSTALL_DIR ?= /opt/poky/esdk

# --- kas-container -----------------------------------------------------------
KAS_CONTAINER     := $(CURDIR)/kas-container
KAS_CONTAINER_URL  = https://raw.githubusercontent.com/siemens/kas/refs/tags/$(KAS_VERSION)/kas-container

# All KAS operations go through kas-container which handles Docker volume
# mounts, UID/GID remapping, and build-dir env vars automatically.
KAS_ENV = \
	KAS_CONTAINER_IMAGE=$(KAS_IMAGE) \
	KAS_BUILD_DIR=$(BUILD_DIR) \
	DL_DIR=$(DL_DIR) \
	SSTATE_DIR=$(SSTATE_DIR) \
	KAS_SSH_DIR=$(HOME)/.ssh

KAS_RUN = $(KAS_ENV) $(KAS_CONTAINER)

# --- Internal helpers --------------------------------------------------------
# Split IMAGE_NAME:TAG once so every sub-make call is consistent.
_KAS_IMAGE_NAME  := $(firstword $(subst :, ,$(KAS_IMAGE)))
_KAS_IMAGE_TAG   := $(lastword  $(subst :, ,$(KAS_IMAGE)))
_SDK_IMAGE_NAME  := $(firstword $(subst :, ,$(SDK_IMAGE)))
_SDK_IMAGE_TAG   := $(lastword  $(subst :, ,$(SDK_IMAGE)))
_ESDK_IMAGE_NAME := $(firstword $(subst :, ,$(ESDK_IMAGE)))
_ESDK_IMAGE_TAG  := $(lastword  $(subst :, ,$(ESDK_IMAGE)))

# =============================================================================
# Targets
# =============================================================================
.PHONY: all build rebuild-image \
        kas-image image ensure-image \
        sdk-image ensure-sdk-image \
        esdk-image ensure-esdk-image \
        kas-container-script shell flash sdk esdk swu \
        deploy-images deploy-sdk deploy-esdk deploy-swu \
        clean clean-build clean-docker clean-all \
        completion help \
		lint lint-makefile lint-yaml lint-swupdate-sync lint-reproducibility \
        test validate check-board

all: build

# -----------------------------------------------------------------------------
# kas-container helper script
# -----------------------------------------------------------------------------

## Download the kas-container script (once, cached in project root)
kas-container-script:
	@if [ ! -f $(KAS_CONTAINER) ]; then \
	    echo "Downloading kas-container $(KAS_VERSION) ..."; \
	    curl -fsSL $(KAS_CONTAINER_URL) -o $(KAS_CONTAINER); \
	    chmod +x $(KAS_CONTAINER); \
	    echo "  Saved: $(KAS_CONTAINER)"; \
	fi

# -----------------------------------------------------------------------------
# Docker image targets
# -----------------------------------------------------------------------------

## Build (or rebuild) the KAS Yocto build container (docker/yocto/)
kas-image:
	$(MAKE) -C docker/yocto \
	    IMAGE_NAME=$(_KAS_IMAGE_NAME) \
	    IMAGE_TAG=$(_KAS_IMAGE_TAG) \
	    KAS_VERSION=$(KAS_VERSION)

## Build the KAS image only when it is absent (used internally by build/shell/sdk/esdk)
ensure-image:
	@command -v docker >/dev/null 2>&1 || { \
	    echo "ERROR: 'docker' not found in PATH.  Install Docker (or set KAS_CONTAINER_ENGINE=podman)."; \
	    exit 1; }
	@docker image inspect $(KAS_IMAGE) >/dev/null 2>&1 \
	    || { echo "KAS image $(KAS_IMAGE) not found — building ..."; \
	         $(MAKE) kas-image; }

## Build the Yocto SD card image for BOARD — alias for build
## Usage: make image rpi5
image: build

## Full chain: Yocto SDK build → stage installer → docker build → deploy
##   Step 1  ensure the KAS build container is present
##   Step 2  run bitbake populate_sdk inside the container
##   Step 3  locate and stage the SDK installer into docker/sdk/sdk.sh
##   Step 4  build the SDK Docker image
##   Step 5  deploy SDK artifacts to deploy/sdk/BOARD_TS/
sdk-image: ensure-image kas-container-script
	@echo ""
	@echo "======================================================================"
	@echo " sdk-image: building Yocto SDK + Docker image for $(SDK_IMAGE)"
	@echo "======================================================================"
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	@echo ""
	@echo "[1/4] Building Yocto SDK (bitbake populate_sdk) ..."
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk $(IMAGE_TARGET)"
	@echo ""
	@echo "[2/4] Staging SDK installer into docker/sdk/ ..."
	$(eval _SDK_SH := $(shell find $(BUILD_DIR)/tmp/deploy/sdk -maxdepth 1 \
	    -name '*.sh' ! -name '*-ext-*' 2>/dev/null | sort -V | tail -1))
	@test -n "$(_SDK_SH)" || \
	    { echo "ERROR: SDK installer (.sh) not found in $(BUILD_DIR)/tmp/deploy/sdk"; exit 1; }
	@echo "  Source : $(_SDK_SH)"
	@echo "  Dest   : docker/sdk/sdk.sh"
	@cp "$(_SDK_SH)" docker/sdk/sdk.sh && chmod +x docker/sdk/sdk.sh
	@echo ""
	@echo "[3/4] Building SDK Docker image $(SDK_IMAGE) ..."
	$(MAKE) -C docker/sdk \
	    IMAGE_NAME=$(_SDK_IMAGE_NAME) \
	    IMAGE_TAG=$(_SDK_IMAGE_TAG) \
	    SDK_INSTALL_DIR=$(SDK_INSTALL_DIR)
	@echo ""
	@echo "[4/4] Deploying SDK artifacts to deploy/sdk/ ..."
	@$(MAKE) --no-print-directory deploy-sdk DEPLOY_TS=$(DEPLOY_TS)
	@echo ""
	@echo "======================================================================"
	@echo " sdk-image: complete → $(SDK_IMAGE)"
	@echo "======================================================================"
	@echo ""

## Full chain: Yocto eSDK build → stage installer → docker build → deploy
##   Step 1  ensure the KAS build container is present
##   Step 2  run bitbake populate_sdk_ext inside the container
##   Step 3  locate and stage the eSDK installer into docker/esdk/esdk.sh
##   Step 4  build the eSDK Docker image
##   Step 5  deploy eSDK artifacts to deploy/esdk/BOARD_TS/
esdk-image: ensure-image kas-container-script
	@echo ""
	@echo "======================================================================"
	@echo " esdk-image: building Yocto eSDK + Docker image for $(ESDK_IMAGE)"
	@echo "======================================================================"
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	@echo ""
	@echo "[1/4] Building Yocto eSDK (bitbake populate_sdk_ext) ..."
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk_ext $(IMAGE_TARGET)"
	@echo ""
	@echo "[2/4] Staging eSDK installer into docker/esdk/ ..."
	$(eval _ESDK_SH := $(shell find $(BUILD_DIR)/tmp/deploy/sdk -maxdepth 1 \
	    -name '*-ext-*.sh' 2>/dev/null | sort -V | tail -1))
	@test -n "$(_ESDK_SH)" || \
	    { echo "ERROR: eSDK installer (*-ext-*.sh) not found in $(BUILD_DIR)/tmp/deploy/sdk"; exit 1; }
	@echo "  Source : $(_ESDK_SH)"
	@echo "  Dest   : docker/esdk/esdk.sh"
	@cp "$(_ESDK_SH)" docker/esdk/esdk.sh && chmod +x docker/esdk/esdk.sh
	@echo ""
	@echo "[3/4] Building eSDK Docker image $(ESDK_IMAGE) ..."
	$(MAKE) -C docker/esdk \
	    IMAGE_NAME=$(_ESDK_IMAGE_NAME) \
	    IMAGE_TAG=$(_ESDK_IMAGE_TAG) \
	    ESDK_INSTALL_DIR=$(ESDK_INSTALL_DIR)
	@echo ""
	@echo "[4/4] Deploying eSDK artifacts to deploy/esdk/ ..."
	@$(MAKE) --no-print-directory deploy-esdk DEPLOY_TS=$(DEPLOY_TS)
	@echo ""
	@echo "======================================================================"
	@echo " esdk-image: complete → $(ESDK_IMAGE)"
	@echo "======================================================================"
	@echo ""

## Build the SDK Docker image only when it is absent
ensure-sdk-image:
	@command -v docker >/dev/null 2>&1 || { \
	    echo "ERROR: 'docker' not found in PATH.  Install Docker (or set KAS_CONTAINER_ENGINE=podman)."; \
	    exit 1; }
	@docker image inspect $(SDK_IMAGE) >/dev/null 2>&1 \
	    || { echo "SDK image $(SDK_IMAGE) not found — running full sdk-image chain ..."; \
	         $(MAKE) sdk-image; }

## Build the eSDK Docker image only when it is absent
ensure-esdk-image:
	@command -v docker >/dev/null 2>&1 || { \
	    echo "ERROR: 'docker' not found in PATH.  Install Docker (or set KAS_CONTAINER_ENGINE=podman)."; \
	    exit 1; }
	@docker image inspect $(ESDK_IMAGE) >/dev/null 2>&1 \
	    || { echo "eSDK image $(ESDK_IMAGE) not found — running full esdk-image chain ..."; \
	         $(MAKE) esdk-image; }

# -----------------------------------------------------------------------------
# Yocto build targets
# -----------------------------------------------------------------------------

## Build the Yocto image for the selected BOARD (default target)
build: ensure-image kas-container-script
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) build $(KAS_CONFIG)
	@$(MAKE) --no-print-directory deploy-images DEPLOY_TS=$(DEPLOY_TS)

## Clean sstate for the image recipe then rebuild (use after adding packages)
rebuild-image: ensure-image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c cleansstate $(IMAGE_TARGET)"
	$(KAS_RUN) build $(KAS_CONFIG)
	@$(MAKE) --no-print-directory deploy-images DEPLOY_TS=$(DEPLOY_TS)

## Interactive shell inside the KAS build container
shell: ensure-image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG)

## Build the cross-toolchain SDK installer and deploy it (no Docker image)
## Use 'make sdk-image' to also build the SDK Docker image.
sdk: ensure-image kas-container-script
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk $(IMAGE_TARGET)"
	@$(MAKE) --no-print-directory deploy-sdk DEPLOY_TS=$(DEPLOY_TS)

## Build the extensible SDK installer and deploy it (no Docker image)
## Use 'make esdk-image' to also build the eSDK Docker image.
esdk: ensure-image kas-container-script
	@mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -c populate_sdk_ext $(IMAGE_TARGET)"
	@$(MAKE) --no-print-directory deploy-esdk DEPLOY_TS=$(DEPLOY_TS)

## Build a .swu OTA update package from the latest rootfs.ext4 image
## Usage: make swu   or   make swu SWU_VERSION=1.2.3
swu: build
	# The bundled SWUpdate flow writes an inactive rootfs slot and is only
	# defined for boards that select sdimage-rpi5.wks.
	@case "$(BOARD)" in \
	    rpi5|cm5) ;; \
	    *) echo "ERROR: SWUpdate A/B bundles are supported only for BOARD=rpi5 or BOARD=cm5 (BOARD=$(BOARD))."; \
	       echo "  This board does not select the A/B WIC layout required by the bundled OTA scripts."; \
	       exit 1 ;; \
	esac
	# Issue #111: fail closed if the SWU_KERNEL/SWU_DTB table at the
	# top of this file does not have an entry for $(BOARD).  Building
	# a .swu without the kernel/DTB inclusion produces a package that
	# SWUpdate cannot install (rawfile 'file not found' — see sw-description
	# templating fix in issue #112).  The operator can override on the
	# command line once they have confirmed the kernel/DTB filename in
	# the deploy dir.
	@test -n "$(SWU_KERNEL)" || { \
	    echo "ERROR: SWU_KERNEL is undefined for BOARD=$(BOARD)."; \
	    echo "  Either: (a) add an entry to the per-board table near the top of this Makefile,"; \
	    echo "  Or:     (b) override on the command line:"; \
	    echo "             make swu $(BOARD) SWU_KERNEL=kernel*.img SWU_DTB=bcm*.dtb"; \
	    exit 1; }
	@test -n "$(SWU_DTB)" || { \
	    echo "ERROR: SWU_DTB is undefined for BOARD=$(BOARD)."; \
	    echo "  See SWU_KERNEL message above for resolution."; \
	    exit 1; }
	$(eval ROOTFS := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -name "acadia-image-$(MACHINE)*.rootfs.ext4" \
	    -o -name "core-image-full-cmdline-$(MACHINE)*.rootfs.ext4" 2>/dev/null \
	    | sort -V | tail -1))
	@test -n "$(ROOTFS)" || \
	    { echo "ERROR: No .rootfs.ext4 found. Ensure 'ext4' is in IMAGE_FSTYPES."; exit 1; }
	@echo "Packaging OTA update from: $(ROOTFS)"
	@mkdir -p $(BUILD_DIR)/swu

	# --- rootfs ---
	@gzip -kfc "$(ROOTFS)" > "$(BUILD_DIR)/swu/rootfs.ext4.gz"

	# --- kernel + DTB (required for I3: kernel/DTB included in OTA) ---
	# Filenames are board-specific (see SWU_KERNEL / SWU_DTB table at
	# top of file).  Issue #63.
				$(eval KERNEL := $(shell if [ "$(BOARD)" = rpi5 ] || [ "$(BOARD)" = cm5 ]; then \
						find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \( -name "$(SWU_KERNEL)" -o -name "Image-*.bin" \); \
					else \
						find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) -name "$(SWU_KERNEL)"; \
					fi 2>/dev/null | sort -V | tail -1))
	$(eval DTB := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -name "$(SWU_DTB)" 2>/dev/null | sort -V | tail -1))
	@test -n "$(KERNEL)" || \
	    { echo "ERROR: $(SWU_KERNEL) not found in the deploy directory for BOARD=$(BOARD)."; exit 1; }
	@test -n "$(DTB)" || \
	    { echo "ERROR: $(SWU_DTB) not found in the deploy directory for BOARD=$(BOARD)."; exit 1; }
	@cp "$(KERNEL)" "$(BUILD_DIR)/swu/$(SWU_KERNEL)"
	@cp "$(DTB)"    "$(BUILD_DIR)/swu/$(SWU_DTB)"

	# --- sw-description ---
	# Issue #113: sw-description is templated on the per-board
	# kernel/DTB filenames (in addition to the version).  Without
	# @@KERNEL@@/@@DTB@@ substitution the .swu would reference
	# filenames that don't exist in the cpio for any non-rpi5 board.
	@sed -e "s|@@VERSION@@|$(SWU_VERSION)|" \
	     -e "s|@@KERNEL@@|$(SWU_KERNEL)|g" \
	     -e "s|@@DTB@@|$(SWU_DTB)|g" \
	    meta/meta-acadia/swupdate/sw-description \
	    > "$(BUILD_DIR)/swu/sw-description"
	@cp meta/meta-acadia/swupdate/pre-install.sh  "$(BUILD_DIR)/swu/"
	@cp meta/meta-acadia/swupdate/post-install.sh "$(BUILD_DIR)/swu/"

	# --- RSA signing (C2 / Issue #21) ---
	# Production builds MUST ship a signed .swu: the target's swupdate
	# daemon is configured to verify signatures against
	# /etc/swupdate/swupdate-public.pem, and an unsigned package is
	# rejected on install.  Fail closed (exit 1) if the operator has
	# not provided a private key — a warning is not enough because
	# the resulting .swu is unusable on a production device.
	@if [ ! -f "meta/meta-acadia/swupdate/keys/swupdate-private.pem" ]; then \
	    echo "" >&2; \
	    echo "ERROR: SWUpdate private key missing." >&2; \
	    echo "  Expected: meta/meta-acadia/swupdate/keys/swupdate-private.pem" >&2; \
	    echo "  Generate: scripts/generate-swu-keys.sh" >&2; \
	    echo "  Or set    SWU_ALLOW_UNSIGNED=1 to build a dev-only .swu (target will reject it)." >&2; \
	    echo "" >&2; \
	    test "$(SWU_ALLOW_UNSIGNED)" = "1" || exit 1; \
	fi
	@if [ -f "meta/meta-acadia/swupdate/keys/swupdate-private.pem" ]; then \
	    echo "Signing sw-description with RSA-4096 ..."; \
	    openssl dgst -sha256 \
	        -sign "meta/meta-acadia/swupdate/keys/swupdate-private.pem" \
	        -out  "$(BUILD_DIR)/swu/sw-description.sig" \
	        "$(BUILD_DIR)/swu/sw-description"; \
	    cd "$(BUILD_DIR)/swu" && \
	        printf 'sw-description\nsw-description.sig\npre-install.sh\npost-install.sh\nrootfs.ext4.gz\n$(SWU_KERNEL)\n$(SWU_DTB)\n' | \
	        cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	else \
	    echo "Building UNSIGNED .swu (SWU_ALLOW_UNSIGNED=1; target will REJECT it) ..."; \
	    cd "$(BUILD_DIR)/swu" && \
	        printf 'sw-description\npre-install.sh\npost-install.sh\nrootfs.ext4.gz\n$(SWU_KERNEL)\n$(SWU_DTB)\n' | \
	        cpio -ov -H newc > "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"; \
	fi
	@echo "OTA package: $(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu"
	@$(MAKE) --no-print-directory deploy-swu DEPLOY_TS=$(DEPLOY_TS)


## Flash to SD card.  Usage: make flash rpi5 DEVICE=/dev/sdX
flash:
ifndef DEVICE
	$(error DEVICE is not set — example: make flash DEVICE=/dev/sdb)
endif
	@test -b "$(DEVICE)" || \
	    { echo "ERROR: '$(DEVICE)' is not a block device."; exit 1; }
	$(eval WIC := $(shell find $(BUILD_DIR)/tmp/deploy/images/$(MACHINE) \
	    -name "*.wic.bz2" 2>/dev/null | sort -V | tail -1))
	@test -n "$(WIC)" || \
	    { echo "ERROR: no .wic.bz2 found in $(BUILD_DIR)/tmp/deploy/images/$(MACHINE)"; exit 1; }
	@echo "Flashing $(WIC) → $(DEVICE)"
	bmaptool copy --bmap "$(WIC:.bz2=.bmap)" "$(WIC)" "$(DEVICE)"

# -----------------------------------------------------------------------------
# Artifact deployment (called automatically; can also be invoked manually)
# -----------------------------------------------------------------------------

## Copy .wic SD card images → deploy/images/BOARD_TS/
deploy-images:
	@src="$(BUILD_DIR)/tmp/deploy/images/$(MACHINE)"; \
	 out="$(DEPLOY_DIR)/images/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No image artifacts at $$src"; exit 1; }; \
	 echo "Deploying SD card images → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     \( -name "*.wic.bz2" -o -name "*.wic.bmap" \) \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy cross-toolchain SDK installer → deploy/sdk/BOARD_TS/
deploy-sdk:
	@src="$(BUILD_DIR)/tmp/deploy/sdk"; \
	 out="$(DEPLOY_DIR)/sdk/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No SDK artifacts at $$src"; exit 1; }; \
	 echo "Deploying SDK → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     -name '*.sh' ! -name '*-ext-*' \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy extensible SDK installer → deploy/esdk/BOARD_TS/
deploy-esdk:
	@src="$(BUILD_DIR)/tmp/deploy/sdk"; \
	 out="$(DEPLOY_DIR)/esdk/$(BOARD)_$(DEPLOY_TS)"; \
	 test -d "$$src" || { echo "ERROR: No eSDK artifacts at $$src"; exit 1; }; \
	 echo "Deploying eSDK → $$out ..."; \
	 mkdir -p "$$out"; \
	 find "$$src" -maxdepth 1 \( -type f -o -type l \) \
	     -name '*-ext-*.sh' \
	     -exec cp -L {} "$$out/" \;; \
	 echo "  Done: $$out"

## Copy .swu OTA package → deploy/swu/BOARD_TS/
deploy-swu:
	@out="$(DEPLOY_DIR)/swu/$(BOARD)_$(DEPLOY_TS)"; \
	 echo "Deploying SWU → $$out ..."; \
	 mkdir -p "$$out"; \
	 cp -L "$(BUILD_DIR)/$(BOARD)-$(SWU_VERSION).swu" "$$out/"; \
	 echo "  Done: $$out"

# -----------------------------------------------------------------------------
# Clean targets
# -----------------------------------------------------------------------------

## Remove build/  (alias for clean-build)
clean: clean-build

## Remove the build output directory
clean-build:
	rm -rf $(BUILD_DIR)

## Remove all three Docker images (kas, sdk, esdk)
clean-docker:
	docker rmi -f $(KAS_IMAGE) $(SDK_IMAGE) $(ESDK_IMAGE) 2>/dev/null || true

## Remove build/ and cache/downloads/ and cache/sstate-cache/
clean-all: clean-build
	rm -rf $(DL_DIR) $(SSTATE_DIR)

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

## Install bash tab-completion (appends a source line to ~/.bashrc)
completion:
	@RCFILE="$$HOME/.bashrc"; \
	 LINE="source \"$(CURDIR)/rpi-make-completion.bash\""; \
	 if grep -qF "$$LINE" "$$RCFILE" 2>/dev/null; then \
	     echo "Completion already enabled in $$RCFILE"; \
	 else \
	     printf '\n# rpi Makefile tab-completion\n%s\n' "$$LINE" >> "$$RCFILE"; \
	     echo "Added to $$RCFILE — run: source $$RCFILE"; \
	 fi

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
# Issue #116: assert the .swu-side copy of pre/post-install.sh in
# meta/meta-acadia/swupdate/ matches the recipe-side copy under
# meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/.
# The two copies exist because the Makefile packages the .swu
# directly from meta-acadia/swupdate/ while the recipe installs
# them to /usr/lib/swupdate/ via SRC_URI.  Per CLAUDE.md C1, drift
# between them silently regresses the rollback chain — only this
# target catches it.
lint-swupdate-sync:
	@set -e; \
	for script in pre-install.sh post-install.sh; do \
	    a="meta/meta-acadia/swupdate/$$script"; \
	    b="meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/$$script"; \
	    if [ ! -f "$$a" ]; then \
	        echo "ERROR: $$a missing"; exit 1; \
	    fi; \
	    if [ ! -f "$$b" ]; then \
	        echo "ERROR: $$b missing"; exit 1; \
	    fi; \
	    if ! diff -q "$$a" "$$b" >/dev/null; then \
	        echo "ERROR: $$script has drifted between .swu-side and recipe-side copies:"; \
	        echo "  .swu-side:    $$a"; \
	        echo "  recipe-side:  $$b"; \
	        echo "Fix: edit one and 'cp' it over the other, or rework the recipe to pull"; \
	        echo "     from meta/meta-acadia/swupdate/ directly (see issue #116)."; \
	        exit 1; \
	    fi; \
	    echo "  OK: $$script in sync"; \
	done

lint: lint-swupdate-sync lint-makefile lint-yaml lint-reproducibility

## Reject AUTOREV in project recipes. Every active git recipe must use a
## reviewed 40-character SHA so builds are reproducible and metadata parsing
## does not perform a network lookup. The intentionally disabled
## acadia-client recipe uses a fixed zero SHA and is not matched here.
lint-reproducibility:
	@matches="$$(grep -R -nE '^[[:space:]]*SRCREV[^#]*=[^#]*\$\{AUTOREV\}' \
	    meta/meta-acadia/recipes-* --include='*.bb' --include='*.bbappend' 2>/dev/null || true)"; \
	if [ -n "$$matches" ]; then \
	    echo "ERROR: AUTOREV is not allowed in project recipes:"; \
	    echo "$$matches"; \
	    exit 1; \
	fi; \
	echo "  OK: no AUTOREV SRCREV values found"

## Validate Makefile syntax — parses the full Makefile (all includes,
## conditionals, and variable expansions) without executing any recipe.
## feature.txt §12: "Makefile syntax validation through make lint".
lint-makefile:
	@$(MAKE) -pn >/dev/null 2>&1 \
	    && echo "  OK: Makefile syntax valid" \
	    || { echo "ERROR: Makefile failed to parse"; exit 1; }

## Validate YAML syntax for common, board, and repo kas configuration
## files (feature.txt §12: "YAML validation for common, target, and
## repository configuration files"). Runs inside the KAS container so
## PyYAML does not need to be installed on the host.
lint-yaml: ensure-image
	@echo "Validating YAML syntax (kas/common.yaml, kas/boards/*.yaml, kas/repos/*.yaml) ..."
	@docker run --rm -v $(CURDIR):/w -w /w $(KAS_IMAGE) \
	    python3 scripts/validate-yaml.py kas/common.yaml kas/boards/*.yaml kas/repos/*.yaml

## Check host prerequisites — Docker and curl (feature.txt §12:
## "Prerequisite checks for Docker and curl through make test").
test:
	@echo "Checking prerequisites ..."
	@command -v docker >/dev/null 2>&1 \
	    && echo "  OK: docker found ($$(docker --version))" \
	    || { echo "  FAIL: docker not found in PATH"; exit 1; }
	@command -v curl >/dev/null 2>&1 \
	    && echo "  OK: curl found ($$(curl --version | head -1))" \
	    || { echo "  FAIL: curl not found in PATH"; exit 1; }
	@echo "All prerequisites satisfied."

## Validate every board's kas configuration: the file exists and has a
## non-empty 'machine:' field (feature.txt §12: "Automatic validation of
## every target configuration and its MACHINE field" / "Target
## configuration validation through make check-board").
check-board:
	@echo "Validating board configurations ..."
	@fail=0; \
	for f in kas/boards/*.yaml; do \
	    board=$$(basename "$$f" .yaml); \
	    m=$$(grep '^machine:' "$$f" 2>/dev/null | awk '{print $$2}'); \
	    if [ -z "$$m" ]; then \
	        echo "  FAIL: $$f has no 'machine:' field"; \
	        fail=1; \
	    else \
	        echo "  OK: $$board -> MACHINE=$$m"; \
	    fi; \
	done; \
	test "$$fail" -eq 0 || { echo "ERROR: one or more board configs failed validation"; exit 1; }

## Validate BitBake metadata (parse-only, no build) for the selected
## BOARD, plus a static check that the middleware/cloud/debug/SDK/ptest
## features (§6, §8) are wired into the image recipe.
## feature.txt §12: "BitBake metadata validation through make validate" /
## "Validation of middleware, cloud, debug, SDK, development-package,
## and ptest features".
validate: check-board ensure-image kas-container-script
	@echo "Parsing BitBake metadata for BOARD=$(BOARD) (MACHINE=$(MACHINE)) ..."
	$(KAS_RUN) shell $(KAS_CONFIG) -c "bitbake -p"
	@echo ""
	@echo "Checking feature wiring in $(IMAGE_TARGET) recipe ..."
	@img="meta/meta-acadia/recipes-core/images/acadia-image.bb"; \
	 fail=0; \
	 for token in packagegroup-acadia-middleware packagegroup-acadia-cloud tools-debug ptest-pkgs; do \
	     grep -qF "$$token" "$$img" || { echo "  FAIL: $$token not referenced in $$img"; fail=1; }; \
	 done; \
	 if [ "$$fail" -eq 0 ]; then \
	     echo "  OK: middleware/cloud/debug/ptest features present"; \
	 else \
	     echo "ERROR: feature validation failed"; exit 1; \
	 fi

help:
	@printf "\nUsage: make <target> <board>\n"
	@printf "\n  Examples:\n"
	@printf "    make image  rpi5\n"
	@printf "    make sdk    rpi4-64\n"
	@printf "    make esdk   rpi3-64\n"
	@printf "    make flash  rpi5 DEVICE=/dev/sdb\n"
	@printf "\nYocto build:\n"
	@printf "  %-24s %s\n" "image"              "Build Yocto SD card image for BOARD  (alias for build)"
	@printf "  %-24s %s\n" "build"              "Build Yocto SD card image for BOARD"
	@printf "  %-24s %s\n" "rebuild-image"      "cleansstate image recipe, then rebuild"
	@printf "  %-24s %s\n" "sdk"                "Build cross-toolchain SDK → deploy/sdk/"
	@printf "  %-24s %s\n" "esdk"               "Build extensible SDK     → deploy/esdk/"
	@printf "  %-24s %s\n" "shell"              "Interactive kas shell in the build container"
	@printf "  %-24s %s\n" "swu"                "Build .swu OTA package  [SWU_VERSION=YYYYMMDDHHMM]"
	@printf "  %-24s %s\n" "flash"              "Flash SD card  (requires DEVICE=/dev/sdX)"
	@printf "\nDocker images:\n"
	@printf "  %-24s %s\n" "kas-image"          "Build/rebuild KAS build container  (docker/yocto/)"
	@printf "  %-24s %s\n" "ensure-image"       "Build KAS image only when absent"
	@printf "  %-24s %s\n" "sdk-image"          "Full chain: SDK build → stage → docker build → deploy"
	@printf "  %-24s %s\n" "ensure-sdk-image"   "Run sdk-image chain only when image is absent"
	@printf "  %-24s %s\n" "esdk-image"         "Full chain: eSDK build → stage → docker build → deploy"
	@printf "  %-24s %s\n" "ensure-esdk-image"  "Run esdk-image chain only when image is absent"
	@printf "\nDeployment (called automatically; can also be run manually):\n"
	@printf "  %-24s %s\n" "deploy-images"      "Copy .wic artifacts → deploy/images/BOARD_TS/"
	@printf "  %-24s %s\n" "deploy-sdk"         "Copy SDK installer   → deploy/sdk/BOARD_TS/"
	@printf "  %-24s %s\n" "deploy-esdk"        "Copy eSDK installer  → deploy/esdk/BOARD_TS/"
	@printf "  %-24s %s\n" "deploy-swu"         "Copy .swu package    → deploy/swu/BOARD_TS/"
	@printf "\nClean:\n"
	@printf "  %-24s %s\n" "clean"              "Remove build/"
	@printf "  %-24s %s\n" "clean-docker"       "Remove kas/sdk/esdk Docker images"
	@printf "  %-24s %s\n" "clean-all"          "Remove build/ and cache/downloads/ and cache/sstate-cache/"
	@printf "\nUtilities:\n"
	@printf "  %-24s %s\n" "completion"         "Install bash tab-completion into ~/.bashrc"
	@printf "\nLinting:\n"
	@printf "  %-24s %s\n" "lint"               "Run all lint checks (Makefile syntax, YAML, swupdate sync)"
	@printf "  %-24s %s\n" "lint-makefile"      "Validate Makefile syntax"
	@printf "  %-24s %s\n" "lint-yaml"          "Validate kas YAML configuration syntax"
	@printf "  %-24s %s\n" "lint-swupdate-sync" "Assert .swu-side and recipe-side pre/post-install.sh match"
	@printf "  %-24s %s\n" "lint-reproducibility" "Reject AUTOREV source revisions"
	@printf "\nValidation:\n"
	@printf "  %-24s %s\n" "test"               "Check host prerequisites (docker, curl)"
	@printf "  %-24s %s\n" "check-board"        "Validate every board's kas config has a MACHINE field"
	@printf "  %-24s %s\n" "validate"           "Parse BitBake metadata + check middleware/cloud/debug/ptest wiring"
	@printf "\nBoards:\n"
	@printf "  rpi5  rpi4-64  rpi4  rpi3-64  rpi3  rpi2\n"
	@printf "  rpi0-2w-64  rpi0-2w  rpi0-wifi  rpi0  rpi1\n"
	@printf "  rpi-armv7  rpi-armv8  cm1  cm3  cm5\n"
	@printf "\n"

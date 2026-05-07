# --- Configuration -----------------------------------------------------------
KAS_IMAGE        ?= rpi5-kas:latest
KAS_CONFIG       := kas/rpi5.yaml
MACHINE          := raspberrypi5

BUILD_DIR        ?= $(CURDIR)/build
DL_DIR           ?= $(CURDIR)/downloads
SSTATE_DIR       ?= $(CURDIR)/sstate-cache

# kas-container script — downloaded once into the project root
KAS_CONTAINER    := $(CURDIR)/kas-container
KAS_CONTAINER_URL = https://raw.githubusercontent.com/siemens/kas/master/kas-container

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
.PHONY: all build rebuild-image image kas-container-script shell flash clean clean-all help

all: build

## Download the kas-container helper script (once)
kas-container-script:
	@if [ ! -f $(KAS_CONTAINER) ]; then \
	    echo "Downloading kas-container script..."; \
	    curl -fsSL $(KAS_CONTAINER_URL) -o $(KAS_CONTAINER); \
	    chmod +x $(KAS_CONTAINER); \
	fi

## Build the KAS Docker image
image:
	$(MAKE) -C docker \
	    IMAGE_NAME=$(firstword $(subst :, ,$(KAS_IMAGE))) \
	    IMAGE_TAG=$(lastword  $(subst :, ,$(KAS_IMAGE)))

## Build the RPi5 Yocto image
build: image kas-container-script
	mkdir -p $(BUILD_DIR) $(DL_DIR) $(SSTATE_DIR)
	$(KAS_RUN) build $(KAS_CONFIG)

## Clean sstate for the image recipe then rebuild  (use after adding packages)
rebuild-image: image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG) -- bitbake -c cleansstate core-image-full-cmdline
	$(KAS_RUN) build $(KAS_CONFIG)

## Interactive shell inside the build container
shell: image kas-container-script
	$(KAS_RUN) shell $(KAS_CONFIG)

## Flash to SD card.  Usage: make flash DEVICE=/dev/sdX
flash:
ifndef DEVICE
	$(error DEVICE is not set -- example: make flash DEVICE=/dev/sdb)
endif
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

help:
	@printf "\nUsage: make [target] [VAR=value ...]\n"
	@printf "\nTargets:\n"
	@printf "  %-16s %s\n" "build"          "Build Docker image + Yocto image (default)"
	@printf "  %-16s %s\n" "rebuild-image"  "cleansstate image recipe then rebuild (after adding packages)"
	@printf "  %-16s %s\n" "image"          "Build the KAS Docker image only"
	@printf "  %-16s %s\n" "shell"      "Interactive kas shell in the build container"
	@printf "  %-16s %s\n" "flash"      "Flash SD card  -- requires DEVICE=/dev/sdX"
	@printf "  %-16s %s\n" "clean"      "Remove build/"
	@printf "  %-16s %s\n" "clean-all"  "Remove build/, downloads/, sstate-cache/"
	@printf "\nVariables:\n"
	@printf "  %-20s %s\n" "KAS_IMAGE"  "Docker image  (default: rpi5-kas:latest)"
	@printf "  %-20s %s\n" "BUILD_DIR"  "Build output  (default: ./build)"
	@printf "  %-20s %s\n" "DL_DIR"     "Download cache (default: ./downloads)"
	@printf "  %-20s %s\n" "SSTATE_DIR" "Sstate cache  (default: ./sstate-cache)"
	@printf "\n"

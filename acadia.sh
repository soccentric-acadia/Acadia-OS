#!/bin/bash

# Build the full Acadia image.
# NOTE: acadia-client is excluded from IMAGE_INSTALL until the upstream repo
# (SiliconCentric/Acadia-Client) exists and SRCREV is pinned to a real commit.
# To build acadia-client in isolation once the repo is available:
#   bitbake -c cleansstate acadia-client && bitbake acadia-client
bitbake acadia-image
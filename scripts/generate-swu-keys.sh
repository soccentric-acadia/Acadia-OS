#!/bin/bash
# generate-swu-keys.sh — generate the SWUpdate RSA-4096 keypair.
#
# Issue #21.  Workflow:
#   1. The PRIVATE key (swupdate-private.pem) is committed ONLY to the
#      build/CI vault.  It is .gitignored in meta/meta-acadia/swupdate/keys/.
#   2. The PUBLIC key is committed in two places:
#        - meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-public.pem
#      (committed to the repo, baked into every image at
#       /etc/swupdate/swupdate-public.pem).
#
# On a developer workstation:
#     ./scripts/generate-swu-keys.sh
# This writes the private key to the local swupdate/keys/ directory
# and updates the public key in the recipe's files/ directory.  NEVER
# commit the private key.

set -euo pipefail

PRIV="meta/meta-acadia/swupdate/keys/swupdate-private.pem"
PUB="meta/meta-acadia/recipes-swupdate/rpi5-swupdate-config/files/swupdate-public.pem"

# 4096 bits is what swupdate-start.sh and the recipe's LIC_FILES_CHKSUM
# comment both reference.  Smaller keys are technically valid but
# undermine the integrity guarantee the swupdate.cfg security block
# exists to provide.
BITS=4096

if [ -f "${PRIV}" ]; then
    echo "ERROR: ${PRIV} already exists.  Refusing to overwrite." >&2
    echo "       Delete it first if you really want to regenerate." >&2
    exit 1
fi

mkdir -p "$(dirname "${PRIV}")"
mkdir -p "$(dirname "${PUB}")"

echo "Generating RSA-${BITS} keypair ..."
openssl genrsa -out "${PRIV}" "${BITS}"
openssl rsa -in "${PRIV}" -pubout -out "${PUB}"

echo
echo "Private key (NEVER commit): ${PRIV}"
echo "Public key  (committed):    ${PUB}"
echo
echo "Next steps:"
echo "  1. Verify ${PRIV} is in .gitignore (it is, in"
echo "     meta/meta-acadia/swupdate/keys/.gitignore)."
echo "  2. Stage and commit ONLY ${PUB}:"
echo "       git add ${PUB}"
echo "       git commit -m 'swupdate: rotate RSA public key'"
echo "  3. The CI vault must be updated to hold the new private key."
echo "     Until it is, the build pipeline will sign with whatever"
echo "     private key is in the vault, and the on-device swupdate"
echo "     daemon will reject any .swu signed with a different key."

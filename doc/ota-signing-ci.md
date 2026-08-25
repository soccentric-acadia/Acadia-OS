# OTA Release Signing in CI (Task 43)

Defines the **protected** artifact-signing workflow for OTA releases. The goal:
release keys remain protected (never committed, never in build logs), and CI
signs only approved artifacts with auditable provenance.

## Key model

- **Private key** (`swupdate-private.pem`, RSA-4096) lives ONLY in the build/CI
  vault (GitHub Actions secret / secret store). It is `.gitignored` in
  `meta/meta-acadia/swupdate/keys/.gitignore` and must NEVER be committed.
- **Public key** (`swupdate-public.pem`) is committed and baked into every image
  at `/etc/swupdate/swupdate-public.pem`, which the target swupdate daemon
  verifies signatures against.
- Key generation: `scripts/generate-swu-keys.sh`. It refuses to overwrite an
  existing private key and reminds the operator to commit only the public half.

## Signing authority & provenance

- `make swu <board>` signs `sw-description` with the private key (RSA-4096,
  `openssl dgst -sha256 -sign`) before bundling the cpio. It **fails closed** if
  the private key is absent and `SWU_ALLOW_UNSIGNED != 1` (the target would
  reject an unsigned bundle, so a warning is not enough).
- Release provenance: each `.swu` is signed by CI using the vault key, and the
  build records the source commit SHA + board + version in the deploy dir. The
  root release-preflight (`make release-preflight`) includes the per-repo SHA in
  its auditable manifest.

## CI policy (enforced by `.github/workflows` secret-scan + swu gates)

1. **No private key in the tree**: the secret scan gate fails if a private key
   block is committed anywhere (root `make secret-scan` + OS CI).
2. **Signed artifacts only for release**: CI builds a representative `.swu`
   from the vault key and verifies its signature with `openssl dgst -verify`
   against the committed public key (task 44 gate).
3. **Keys never in logs**: signing never echoes the key; the `SWU_PRIVATE_KEY`
   is passed via an environment variable / mounted secret, not an argument.

## Adding a new signer

A new release key is generated with `generate-swu-keys.sh`, the public half is
committed, the private half is stored in the CI vault as
`SWUPDATE_PRIVATE_KEY` (secret), and the provenance manifest is updated.

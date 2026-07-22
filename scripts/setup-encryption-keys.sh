#!/usr/bin/env bash
#
# Create the Active Record Encryption keys (A7 — Aadhaar encrypted at rest) in
# Google Secret Manager and grant the Cloud Run runtime service account access.
#
# Run this ONCE, from the repo root, BEFORE the first deploy that ships the A7
# encryption initializer (config/initializers/active_record_encryption.rb):
#
#     ./scripts/setup-encryption-keys.sh
#
# cloudbuild.yaml references these by name via --set-secrets. In production the
# initializer does ENV.fetch (no fallback), so WITHOUT these secrets the app and
# the db:migrate job FAIL TO BOOT.
#
# ⚠️  SAFETY: this NEVER overwrites an existing key. Changing the primary or
# deterministic key makes every previously-encrypted Aadhaar value permanently
# unreadable, so the script only *creates* a secret that does not yet exist. Keep
# these keys backed up forever.

set -euo pipefail

PROJECT="thoughtbasics"
RUNTIME_SA="fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com"

# Secret Manager name  ->  ENV var it is mounted as (see cloudbuild.yaml)
SECRETS=(
  "fuel-loyalty-ar-encryption-primary-key"          # AR_ENCRYPTION_PRIMARY_KEY
  "fuel-loyalty-ar-encryption-deterministic-key"    # AR_ENCRYPTION_DETERMINISTIC_KEY
  "fuel-loyalty-ar-encryption-key-derivation-salt"  # AR_ENCRYPTION_KEY_DERIVATION_SALT
)

for name in "${SECRETS[@]}"; do
  if gcloud secrets describe "$name" --project="$PROJECT" >/dev/null 2>&1; then
    echo "• already exists, leaving untouched -> $name"
  else
    # 32 random bytes (64 hex chars) is ample key material for AES-256-GCM
    # derivation. `bin/rails db:encryption:init` is the canonical alternative.
    openssl rand -hex 32 | tr -d '\n' | gcloud secrets create "$name" \
      --project="$PROJECT" --replication-policy=automatic --data-file=-
    echo "✓ created 256-bit key                -> $name"
  fi

  gcloud secrets add-iam-policy-binding "$name" \
    --project="$PROJECT" \
    --member="serviceAccount:${RUNTIME_SA}" \
    --role="roles/secretmanager.secretAccessor" >/dev/null
  echo "  granted secretAccessor to ${RUNTIME_SA}"
done

cat <<'EOF'

Done. The AR_ENCRYPTION_* secrets exist and cloudbuild.yaml mounts them.

BACK THESE UP somewhere durable and private — if they are lost, stored Aadhaar
values can never be decrypted again. Deploy the A7 changes only after this
script has succeeded.
EOF

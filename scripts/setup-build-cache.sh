#!/usr/bin/env bash
#
# Provision the Google Cloud Storage bucket that caches the Android SDK between
# Cloud Build runs, and grant the Cloud Build service account object access.
#
# Run from the repo root (optionally pass a bucket name; default below):
#
#     ./scripts/setup-build-cache.sh [BUCKET_NAME]
#
# WHY A SEPARATE BUCKET: gs://fuel-loyalty-uploads holds A7 operator KYC images
# — PII, with its own retention expectations and an IAM grant to the *runtime*
# service account. Build caches are disposable, written by the *build* service
# account, and safe to delete at any time. Keeping them apart means a lifecycle
# rule that expires cache objects can never touch a customer's ID card.
#
# The AndroidCompile step in cloudbuild.yaml degrades gracefully: if this bucket
# does not exist, or the build SA cannot reach it, the step installs the SDK
# from scratch exactly as before. Caching is an optimisation, never a
# dependency — a cache problem must not be able to fail a deploy.

set -euo pipefail

PROJECT="thoughtbasics"
PROJECT_NUMBER="534102618638"
LOCATION="us-central1"
BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
BUCKET="${1:-fuel-loyalty-build-cache}"

if gcloud storage buckets describe "gs://${BUCKET}" --project="$PROJECT" >/dev/null 2>&1; then
  echo "• bucket already exists -> gs://${BUCKET}"
else
  gcloud storage buckets create "gs://${BUCKET}" \
    --project="$PROJECT" \
    --location="$LOCATION" \
    --uniform-bucket-level-access \
    --public-access-prevention
  echo "✓ created private bucket -> gs://${BUCKET}"
fi

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --member="serviceAccount:${BUILD_SA}" \
  --role="roles/storage.objectAdmin" >/dev/null
echo "  granted storage.objectAdmin to ${BUILD_SA}"

# Expire cache objects so a stale SDK archive cannot accumulate cost forever.
# 30 days is comfortably longer than the gap between deploys; a miss just means
# one slower build that repopulates the cache.
LIFECYCLE_JSON="$(mktemp)"
cat > "$LIFECYCLE_JSON" <<'JSON'
{
  "lifecycle": {
    "rule": [
      { "action": { "type": "Delete" }, "condition": { "age": 30 } }
    ]
  }
}
JSON
gcloud storage buckets update "gs://${BUCKET}" --lifecycle-file="$LIFECYCLE_JSON" >/dev/null
rm -f "$LIFECYCLE_JSON"
echo "  set a 30-day expiry on cache objects"

cat <<EOF

Done. gs://${BUCKET} is ready and Cloud Build can read/write objects.

The AndroidCompile step already points at it via the cloudbuild.yaml
substitution:
    _BUILD_CACHE_BUCKET: '${BUCKET}'

Nothing else to switch on. The next build populates the cache; the one after
that restores it instead of re-downloading the ~250 MB SDK.
EOF

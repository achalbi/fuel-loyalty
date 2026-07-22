#!/usr/bin/env bash
#
# Provision the Google Cloud Storage bucket that backs A7 operator-KYC images in
# production, and grant the Cloud Run runtime service account object access.
#
# Run from the repo root (optionally pass a bucket name; default below):
#
#     ./scripts/setup-gcs.sh [BUCKET_NAME]
#
# The bucket is private (uniform access + public-access-prevention): Active
# Storage serves images only via short-lived signed URLs / the authenticated
# blob redirect — never a permanent public URL, per the A7 spec. Cloud Run uses
# the attached runtime service account for auth (Application Default
# Credentials), so no keyfile is created or committed.
#
# After it succeeds, flip storage on by setting these cloudbuild.yaml
# substitutions and pushing to main:
#     _ACTIVE_STORAGE_SERVICE: 'google'
#     _GCS_BUCKET: '<BUCKET_NAME>'

set -euo pipefail

PROJECT="thoughtbasics"
LOCATION="us-central1"
RUNTIME_SA="fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com"
BUCKET="${1:-fuel-loyalty-uploads}"

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
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/storage.objectAdmin" >/dev/null
echo "  granted storage.objectAdmin to ${RUNTIME_SA}"

# The bucket is private, so Active Storage serves images via V4 signed URLs. Under
# ADC there is no local signing key, so the gem signs through the IAM SignBlob API
# (config/storage.yml `iam: true`), which needs the runtime SA to be able to sign
# for ITSELF. Without this, every KYC image view returns HTTP 500.
gcloud iam service-accounts add-iam-policy-binding "${RUNTIME_SA}" \
  --project="$PROJECT" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/iam.serviceAccountTokenCreator" >/dev/null
echo "  granted iam.serviceAccountTokenCreator (signBlob) to ${RUNTIME_SA}"

cat <<EOF

Done. gs://${BUCKET} is ready and the runtime SA can read/write objects.

NEXT — enable it in production:
  1. In cloudbuild.yaml set:
       _ACTIVE_STORAGE_SERVICE: 'google'
       _GCS_BUCKET: '${BUCKET}'
  2. Push to main (triggers a deploy). New KYC uploads now land in GCS and
     survive Cloud Run restarts.
EOF

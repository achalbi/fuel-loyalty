#!/usr/bin/env bash
#
# Provision the Google Cloud Storage bucket that caches the Android SDK between
# Cloud Build runs, and grant the Cloud Build service account object access.
#
# YOU PROBABLY DO NOT NEED THIS. The BuildCacheBucket step in cloudbuild.yaml
# creates the bucket on first use. This script is the fallback for when the
# build service account cannot create buckets itself: run it once as a human
# with Storage Admin, and the build will find the bucket already there. It also
# grants the build account object access explicitly, which the in-build path
# cannot do for itself.
#
# Run from the repo root (optionally pass a bucket name; default below):
#
#     ./scripts/setup-build-cache.sh [BUCKET_NAME]
#
# Safe to re-run: every step is idempotent, so this doubles as a way to repair
# the bucket's IAM or lifecycle config if either drifts.
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

die() { echo "✗ $*" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
# Fail on the actual cause rather than on a confusing gcloud error three steps
# later.
command -v gcloud >/dev/null 2>&1 \
  || die "gcloud is not installed. See https://cloud.google.com/sdk/docs/install"

gcloud auth print-access-token >/dev/null 2>&1 \
  || die "gcloud is not authenticated. Run: gcloud auth login"

gcloud projects describe "$PROJECT" >/dev/null 2>&1 \
  || die "cannot reach project '${PROJECT}' as $(gcloud config get-value account 2>/dev/null). You need Storage Admin on it."

# The bucket name has to match what the build actually reads, or this script
# provisions a bucket nothing uses.
CONFIGURED="$(sed -n "s/^  _BUILD_CACHE_BUCKET: '\(.*\)'$/\1/p" cloudbuild.yaml 2>/dev/null || true)"
if [ -n "$CONFIGURED" ] && [ "$CONFIGURED" != "$BUCKET" ]; then
  echo "! cloudbuild.yaml points at '${CONFIGURED}', not '${BUCKET}'."
  echo "  Update the _BUILD_CACHE_BUCKET substitution too, or the build will not use this bucket."
fi

# --- bucket ----------------------------------------------------------------
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
trap 'rm -f "$LIFECYCLE_JSON"' EXIT
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
echo "  set a 30-day expiry on cache objects"

# --- verify ----------------------------------------------------------------
# Read the settings back rather than trusting that the calls above did what
# they said. Public exposure of a build cache is low-stakes, but confirming it
# costs one API call.
echo
echo "Verifying:"
# Non-fatal: the bucket is already provisioned by this point, so a hiccup
# reading the settings back must not make a successful run look like a failure.
gcloud storage buckets describe "gs://${BUCKET}" --project="$PROJECT" \
  --format='yaml(location, public_access_prevention, uniform_bucket_level_access, lifecycle_config)' \
  2>/dev/null | sed 's/^/  /' \
  || echo "  (could not read the settings back — check gs://${BUCKET} in the console)"

cat <<EOF

Done. gs://${BUCKET} is ready and Cloud Build can read/write objects.

The AndroidCompile step already points at it via the cloudbuild.yaml
substitution:
    _BUILD_CACHE_BUCKET: '${BUCKET}'

Nothing else to switch on. The next build populates the cache; the one after
that restores it instead of re-downloading the ~250 MB SDK.
EOF

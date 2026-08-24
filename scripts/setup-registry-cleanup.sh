#!/usr/bin/env bash
#
# Apply an Artifact Registry cleanup policy so build images stop accumulating
# forever. Every push to main adds a :COMMIT_SHA image, and the two-pass build
# in cloudbuild.yaml leaves an orphaned :builder version behind each time it
# moves the tag.
#
# Run from the repo root:
#
#     ./scripts/setup-registry-cleanup.sh            # DRY RUN (default)
#     ./scripts/setup-registry-cleanup.sh --apply    # actually delete
#
# DRY RUN IS THE DEFAULT ON PURPOSE. Artifact Registry evaluates the policy and
# logs what it WOULD delete without deleting anything, so you can read the logs
# and confirm the scope before arming it. Deletions are not recoverable.
#
# TWO THINGS THIS POLICY IS CAREFUL ABOUT:
#
# 1. cloud-run-source-deploy is the shared repo Cloud Run source deploys use by
#    default, so it may hold images for services that have nothing to do with
#    this app. Every rule below is scoped with packageNamePrefixes to this
#    service's package. An unscoped policy here could delete another service's
#    images.
#
# 2. Cloud Run rollback needs the image a revision was deployed from. Deleting
#    old :COMMIT_SHA images silently removes the ability to roll back to those
#    revisions, so a Keep rule retains the most recent versions and it takes
#    precedence over the Delete rules (Artifact Registry resolves Keep first).

set -euo pipefail

PROJECT="thoughtbasics"
LOCATION="us-central1"
REPOSITORY="cloud-run-source-deploy"
PACKAGE="achalbi-fuel-loyalty/fuel-loyalty-git"

KEEP_RECENT=30      # rollback headroom, in image versions
UNTAGGED_AGE="7d"   # superseded :builder versions and other orphans
TAGGED_AGE="90d"    # old :COMMIT_SHA images, beyond the Keep window

DRY_RUN=true
case "${1:-}" in
  --apply) DRY_RUN=false ;;
  "")      ;;
  *)       echo "usage: $0 [--apply]" >&2; exit 2 ;;
esac

die() { echo "✗ $*" >&2; exit 1; }

command -v gcloud >/dev/null 2>&1 \
  || die "gcloud is not installed. See https://cloud.google.com/sdk/docs/install"
gcloud auth print-access-token >/dev/null 2>&1 \
  || die "gcloud is not authenticated. Run: gcloud auth login"
gcloud artifacts repositories describe "$REPOSITORY" \
  --project="$PROJECT" --location="$LOCATION" >/dev/null 2>&1 \
  || die "cannot reach ${REPOSITORY} in ${PROJECT}/${LOCATION}. You need Artifact Registry Admin."

POLICY="$(mktemp)"
trap 'rm -f "$POLICY"' EXIT
cat > "$POLICY" <<JSON
[
  {
    "name": "keep-recent-for-rollback",
    "action": { "type": "Keep" },
    "mostRecentVersions": {
      "packageNamePrefixes": ["${PACKAGE}"],
      "keepCount": ${KEEP_RECENT}
    }
  },
  {
    "name": "delete-untagged",
    "action": { "type": "Delete" },
    "condition": {
      "tagState": "UNTAGGED",
      "olderThan": "${UNTAGGED_AGE}",
      "packageNamePrefixes": ["${PACKAGE}"]
    }
  },
  {
    "name": "delete-stale-tagged",
    "action": { "type": "Delete" },
    "condition": {
      "tagState": "TAGGED",
      "olderThan": "${TAGGED_AGE}",
      "packageNamePrefixes": ["${PACKAGE}"]
    }
  }
]
JSON

python3 -m json.tool "$POLICY" >/dev/null 2>&1 || die "generated policy is not valid JSON"

if [ "$DRY_RUN" = true ]; then
  echo "• applying in DRY RUN mode — nothing will be deleted"
  DRY_FLAG="--dry-run"
else
  echo "! applying for REAL — matching versions will be deleted"
  DRY_FLAG="--no-dry-run"
fi

gcloud artifacts repositories set-cleanup-policies "$REPOSITORY" \
  --project="$PROJECT" \
  --location="$LOCATION" \
  --policy="$POLICY" \
  "$DRY_FLAG"

echo
echo "Policy now on ${REPOSITORY} (scoped to ${PACKAGE}):"
printf '  keep      most recent %-6s (rollback headroom)\n'          "${KEEP_RECENT}"
printf '  delete    untagged older than %-6s (superseded :builder)\n' "${UNTAGGED_AGE}"
printf '  delete    tagged   older than %-6s (old :COMMIT_SHA images)\n' "${TAGGED_AGE}"

if [ "$DRY_RUN" = true ]; then
  cat <<EOF

This was a DRY RUN. Artifact Registry will log what it would have deleted
without removing anything. Read those logs first:

    gcloud logging read \\
      'resource.type="artifactregistry.googleapis.com/Repository" AND
       protoPayload.methodName="CleanupPolicy"' \\
      --project=${PROJECT} --limit=50

When the scope looks right, arm it:

    ./scripts/setup-registry-cleanup.sh --apply
EOF
fi

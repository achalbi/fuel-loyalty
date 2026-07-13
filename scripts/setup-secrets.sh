#!/usr/bin/env bash
#
# Migrate the fuel-loyalty deploy secrets into Google Secret Manager and grant
# the Cloud Run runtime service account access to them.
#
# Run this ONCE (before committing the cloudbuild.yaml change), from the repo
# root:
#
#     ./scripts/setup-secrets.sh
#
# It reads the *current* secret values straight from git HEAD, so you don't have
# to paste anything. After it succeeds, the values live only in Secret Manager;
# cloudbuild.yaml references them by name via --set-secrets.
#
# IMPORTANT: the values in git history are compromised. After migrating, ROTATE
# them (see the checklist printed at the end) and re-run this script to add a new
# version — it is idempotent and will "add version" instead of "create".

set -euo pipefail

PROJECT="thoughtbasics"
RUNTIME_SA="fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com"

# secret-manager-name  ->  cloudbuild substitution key it came from
declare -A SECRETS=(
  [fuel-loyalty-secret-key-base]="_SECRET_KEY_BASE"
  [fuel-loyalty-database-url]="_DATABASE_URL"
  [fuel-loyalty-admin-notification-api-token]="_ADMIN_NOTIFICATION_API_TOKEN"
  [fuel-loyalty-plate-recognizer-api-token]="_PLATE_RECOGNIZER_API_TOKEN"
)

# Pull "  _KEY: 'value'" out of the committed cloudbuild.yaml, stripping the key,
# leading whitespace, and surrounding single quotes. Inner ':' and '/' survive
# because we only cut up to the first colon.
extract() {
  git show HEAD:cloudbuild.yaml \
    | grep -E "^[[:space:]]*${1}:" \
    | head -1 \
    | sed -E "s/^[^:]*:[[:space:]]*//; s/^'//; s/'[[:space:]]*$//"
}

for name in "${!SECRETS[@]}"; do
  sub="${SECRETS[$name]}"
  value="$(extract "$sub")"
  if [[ -z "$value" ]]; then
    echo "!! Could not read $sub from HEAD:cloudbuild.yaml — aborting." >&2
    exit 1
  fi

  if gcloud secrets describe "$name" --project="$PROJECT" >/dev/null 2>&1; then
    printf '%s' "$value" | gcloud secrets versions add "$name" \
      --project="$PROJECT" --data-file=- >/dev/null
    echo "↻ added new version   -> $name"
  else
    printf '%s' "$value" | gcloud secrets create "$name" \
      --project="$PROJECT" --replication-policy=automatic --data-file=- >/dev/null
    echo "✓ created secret       -> $name"
  fi

  gcloud secrets add-iam-policy-binding "$name" \
    --project="$PROJECT" \
    --member="serviceAccount:${RUNTIME_SA}" \
    --role="roles/secretmanager.secretAccessor" >/dev/null
  echo "  granted secretAccessor to ${RUNTIME_SA}"
done

cat <<'EOF'

Done. cloudbuild.yaml now sources these from Secret Manager.

NEXT — rotate the exposed values (they are still in git history):
  • DATABASE_URL  : reset the Postgres password in the Supabase dashboard,
                    then: printf '%s' 'postgresql://postgres:NEWPASS@db.pjkwixcnauayaplyhqdt.supabase.co:5432/postgres' \
                            | gcloud secrets versions add fuel-loyalty-database-url --data-file=-
  • SECRET_KEY_BASE: printf '%s' "$(bin/rails secret)" \
                            | gcloud secrets versions add fuel-loyalty-secret-key-base --data-file=-
                    (invalidates existing sessions/signed cookies — users re-login)
  • PLATE_RECOGNIZER_API_TOKEN: rotate in the Plate Recognizer dashboard, then add a new version.
  • ADMIN_NOTIFICATION_API_TOKEN: printf '%s' "$(openssl rand -hex 32)" \
                            | gcloud secrets versions add fuel-loyalty-admin-notification-api-token --data-file=-
                    (update any client that calls the admin-notification API with the new token)

Then push a commit / re-run the Cloud Build trigger so the running service picks up ':latest'.
EOF

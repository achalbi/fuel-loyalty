# A7 Operator-KYC — Production Provisioning Runbook

A7 (operator KYC) needs two things provisioned in the `thoughtbasics` GCP project
**before it can safely run in production**:

1. **Active Record Encryption keys** — Aadhaar is encrypted at rest. The
   production initializer (`config/initializers/active_record_encryption.rb`)
   does `ENV.fetch` with **no fallback**, so without these keys the app *and the
   `db:migrate` job* **fail to boot**. This is a hard gate on the Phase-3 deploy.
2. **Durable object storage (GCS)** — Cloud Run's local disk is ephemeral, so
   KYC images uploaded to `:local` are **lost on every restart/deploy**. Images
   must live in a private GCS bucket.

The application code + deploy pipeline are already wired for both; this runbook
is the one-time operator provisioning. All of it needs your GCP credentials, so
it is not automated in CI.

> **What's already in the repo (no action needed):**
> `cloudbuild.yaml` mounts `AR_ENCRYPTION_*` from Secret Manager and passes
> `ACTIVE_STORAGE_SERVICE` / `GCS_*` env to both the migrate job and the service;
> `config/storage.yml` has a `:google` service (Cloud Run ADC, **no keyfile**);
> `config/environments/production.rb` selects the service from
> `ACTIVE_STORAGE_SERVICE` (default `local`, so a deploy still boots before GCS
> is ready); `Gemfile` has `google-cloud-storage`.

---

## Step 1 — Encryption keys (do this BEFORE the Phase-3 deploy)

```bash
./scripts/setup-encryption-keys.sh
```

Creates three Secret Manager secrets and grants the runtime service account
(`fuel-loyalty-push-runtime@…`) access:

| Secret name | Mounted as |
|---|---|
| `fuel-loyalty-ar-encryption-primary-key` | `AR_ENCRYPTION_PRIMARY_KEY` |
| `fuel-loyalty-ar-encryption-deterministic-key` | `AR_ENCRYPTION_DETERMINISTIC_KEY` |
| `fuel-loyalty-ar-encryption-key-derivation-salt` | `AR_ENCRYPTION_KEY_DERIVATION_SALT` |

- The script **never overwrites** an existing key — rotating the primary or
  deterministic key makes every previously-encrypted Aadhaar **permanently
  unreadable**.
- **Back the keys up** somewhere durable and private. Losing them = losing all
  stored Aadhaar values.

Verify:

```bash
gcloud secrets list --project=thoughtbasics --filter="name~ar-encryption"
```

## Step 2 — GCS bucket (before relying on KYC image capture)

```bash
./scripts/setup-gcs.sh            # defaults to bucket "fuel-loyalty-uploads"
# or: ./scripts/setup-gcs.sh my-bucket-name
```

Creates a **private** bucket (uniform access + public-access-prevention) in
`us-central1` and grants the runtime SA two roles:

- `roles/storage.objectAdmin` — read/write the image objects.
- `roles/iam.serviceAccountTokenCreator` (on itself) — because the bucket is
  private, Active Storage serves every image via a **V4 signed URL**, and under
  Cloud Run ADC there is no local signing key, so the gem signs through the IAM
  **SignBlob** API (enabled by `iam: true` in `config/storage.yml`). Without this
  grant, uploads succeed but every KYC image view returns **HTTP 500**.

Images are thus served only via short-lived signed URLs / the authenticated blob
redirect — never a permanent public URL (per the A7 spec).

Then flip the app onto GCS by editing `cloudbuild.yaml` substitutions:

```yaml
  _ACTIVE_STORAGE_SERVICE: 'google'
  _GCS_BUCKET: 'fuel-loyalty-uploads'   # match the bucket you created
```

Commit + push to `main` → the deploy trigger picks it up.

## Ordering

```
setup-encryption-keys.sh  ──►  merge/deploy Phase 3  ──►  setup-gcs.sh  ──►  flip _ACTIVE_STORAGE_SERVICE=google  ──►  push
        (mandatory:                (app boots,               (bucket +          (KYC images now durable)
     app won't boot w/o it)     KYC works but images      IAM ready)
                                  are ephemeral until
                                       Step 2)
```

Between the Phase-3 deploy and Step 2, KYC capture works but uploaded images do
not survive a restart — do not onboard real operator KYC until GCS is live.

## Verify after enabling GCS

- Create/edit an operator with a profile photo in the admin console.
- Redeploy (or restart the Cloud Run revision) and confirm the photo still
  loads — proves it is in GCS, not the ephemeral disk.
- Confirm the ID-card image opens only through the audited reveal (signed URL),
  never a public bucket URL.

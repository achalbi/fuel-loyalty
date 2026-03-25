# Fuel Loyalty

## Run the app

```bash
export APP_UID="$(id -u)"
export APP_GID="$(id -g)"
docker compose up --build
```

The app will be available at <http://localhost:3000>.

## Run production locally

```bash
docker compose -f docker-compose.prod.yml up --build
```

The production app will be available at <http://localhost:8080>.

## Production deploy checklist

Set these environment variables before deploying a real production instance:

```bash
APP_URL=https://your-domain.example
MAILER_FROM=no-reply@your-domain.example
FIREBASE_API_KEY=AIzaSyD2GOiEjnrGWDPQt1chym04qtmQ3F5LCEQ
FIREBASE_AUTH_DOMAIN=fuel-loyalty.firebaseapp.com
FIREBASE_PROJECT_ID=fuel-loyalty
FIREBASE_STORAGE_BUCKET=fuel-loyalty.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=629935221011
FIREBASE_APP_ID=1:629935221011:web:612bdd301126b28e8492e6
FIREBASE_MEASUREMENT_ID=G-K2Q0927ZJX
FIREBASE_WEB_VAPID_KEY=your-public-web-push-vapid-key
SECRET_KEY_BASE=replace-with-a-real-secret
DATABASE_URL=postgresql://user:password@host:5432/app_production
REDIS_URL=redis://host:6379/0
```

Notes:

- `APP_URL` is used for mailer links, asset URLs, and PWA metadata.
- `MAILER_FROM` controls the sender address for Devise and app mailers.
- `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_APP_ID` come from your Firebase web app config.
- `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, and `FIREBASE_MEASUREMENT_ID` are optional pass-through values from the same Firebase config.
- `FIREBASE_WEB_VAPID_KEY` is the public web push key used by the browser to obtain FCM tokens.
- `SECRET_KEY_BASE` must be a real secret in production. The compose default is only for local testing.
- If you cannot provide `APP_URL`, you can use `APP_HOST` and `APP_PROTOCOL` instead.

Recommended pre-deploy checks:

```bash
docker compose exec -T app bin/rails test
docker compose exec -T app bin/rails zeitwerk:check
docker compose exec -T app bundle exec brakeman -q
docker compose exec -T app bundle exec rails assets:precompile
```

## Cloud Run deploy behavior

`cloudbuild.yaml` now runs `rails db:migrate` automatically on every deploy before
the Cloud Run service is updated.

This is safe to run every time: Rails only applies pending migrations, so if
there are no new migration files, nothing changes in the database.

This is intentionally done in the deploy pipeline, not in the Docker build and
not in the app startup command, so production database changes happen once per
deploy instead of once per container boot.

## Run a production migration manually on Cloud Run

This repo's Cloud Build config targets the Cloud Run service `fuel-loyalty-git`
in `us-central1`. If you ever need to run the same migration step manually, use:

```bash
SERVICE=fuel-loyalty-git
REGION=us-central1
IMAGE="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(spec.template.spec.containers[0].image)')"

gcloud run jobs deploy "${SERVICE}-migrate" \
  --region "$REGION" \
  --image "$IMAGE" \
  --command bundle \
  --args exec,rails,db:migrate \
  --set-env-vars RAILS_ENV=production \
  --set-env-vars RAILS_SERVE_STATIC_FILES=true \
  --set-env-vars APP_URL=https://your-app.example.com \
  --set-env-vars MAILER_FROM=no-reply@your-app.example.com \
  --set-env-vars DATABASE_URL='your-production-database-url' \
  --set-env-vars SECRET_KEY_BASE='your-production-secret-key'

gcloud run jobs execute "${SERVICE}-migrate" --region "$REGION" --wait
```

After the job succeeds, you can remove it:

```bash
gcloud run jobs delete "${SERVICE}-migrate" --region "$REGION"
```

## Useful commands

```bash
docker compose run --rm app bundle exec rails db:prepare
docker compose -f docker-compose.prod.yml up --build
docker compose down
docker compose down -v
```

For the production stack:

```bash
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml down -v
```

## Edge rollout

The repo now includes an incremental edge-cache rollout path for the public loyalty shell. See [docs/edge-cache-rollout.md](/Users/achalindiresh/workspace/fuel-loyalty/docs/edge-cache-rollout.md) for the Cloudflare cache rules, required runtime env vars, and theme-change purge behavior.

## Push notifications

The repo now includes an FCM-backed PWA push notification system with:

- token registration via `/push/subscriptions`
- admin send-now via `/admin/notifications/send`
- on-demand schedules via `/admin/schedules` and `/admin/schedules/run`
- no cron or background workers

Setup details, environment variables, and example requests live in [docs/push-notifications.md](/Users/achalindiresh/workspace/fuel-loyalty/docs/push-notifications.md).

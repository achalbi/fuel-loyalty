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
SECRET_KEY_BASE=replace-with-a-real-secret
DATABASE_URL=postgresql://user:password@host:5432/app_production
REDIS_URL=redis://host:6379/0
```

Notes:

- `APP_URL` is used for mailer links, asset URLs, and PWA metadata.
- `MAILER_FROM` controls the sender address for Devise and app mailers.
- `SECRET_KEY_BASE` must be a real secret in production. The compose default is only for local testing.
- If you cannot provide `APP_URL`, you can use `APP_HOST` and `APP_PROTOCOL` instead.

Recommended pre-deploy checks:

```bash
docker compose exec -T app bin/rails test
docker compose exec -T app bin/rails zeitwerk:check
docker compose exec -T app bundle exec brakeman -q
docker compose exec -T app bundle exec rails assets:precompile
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

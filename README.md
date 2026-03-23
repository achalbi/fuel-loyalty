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

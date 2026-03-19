# Fuel Loyalty

## Run the app

```bash
export APP_UID="$(id -u)"
export APP_GID="$(id -g)"
docker compose up --build
```

The app will be available at <http://localhost:3000>.

## Useful commands

```bash
docker compose run --rm app bundle exec rails db:prepare
docker compose down
docker compose down -v
```

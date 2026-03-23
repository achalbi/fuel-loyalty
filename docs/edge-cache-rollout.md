# Edge Cache Rollout

## Runtime env vars

Set these on the Cloud Run service, not in git:

```bash
PUBLIC_BASE_URL=https://your-app.example.com
CLOUDFLARE_ZONE_ID=your-zone-id
CLOUDFLARE_API_TOKEN=your-api-token
```

`RELEASE_SHA` is now injected by Cloud Build on each deploy and is used to version the service worker cache.

## Cloudflare cache rules

Cache eligible:

- `/assets/*`
- `/manifest.json`
- `/loyalty`

Bypass cache:

- Any request with `Authorization`
- Any request with the Rails session cookie
- Any method other than `GET` or `HEAD`
- `/admin/*`
- `/staff/*`
- `/users/*`
- `/customers/*`
- `/loyalty/result`

Honor origin headers for cache TTLs:

- `/assets/*` should respect `public, max-age=31536000, immutable`
- `/manifest.json` should respect `public, max-age=300, s-maxage=300, stale-while-revalidate=30`
- `/loyalty` should respect `public, max-age=0, s-maxage=60, stale-while-revalidate=30, stale-if-error=86400`

## Purge behavior

When an admin changes the theme color, the app will now attempt to purge:

- `/loyalty`
- `/loyalty?source=pwa`
- `/manifest.json`

If the Cloudflare env vars are missing, the purge is skipped and the app keeps working normally.

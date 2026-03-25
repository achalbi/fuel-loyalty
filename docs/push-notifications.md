# Push Notifications

## Architecture Overview

This app uses Firebase Cloud Messaging (FCM) Web Push for the PWA, with all scheduling handled inside ordinary Rails web requests.

- Device tokens are stored in `push_subscriptions`.
- Manual broadcasts go through `POST /admin/notifications/send`.
- Saved schedules live in `notification_schedules`.
- The scheduler only runs when `POST /admin/schedules/run` is called.
- No Sidekiq, cron, Redis workers, or long-running jobs are required.
- Cloud Run remains stateless because all work happens on demand.

The browser-side Firebase SDK is loaded from the Rails layout using Google-hosted module imports, and the service worker uses the hosted compat scripts because it is still registered as a classic worker. This app does not currently use `npm`, `webpack`, or `Rollup` for Firebase, so you should map the Firebase console snippet into environment variables instead of pasting module-import code into the asset pipeline.

## Rails Components

- Model: `PushSubscription`
- Model: `NotificationSchedule`
- Service: `FirebaseAppConfig`
- Service: `FirebasePushService`
- Service: `NotificationScheduleRunner`
- Controller: `PushSubscriptionsController`
- Controller: `Admin::NotificationDeliveriesController`
- Controller: `Admin::SchedulesController`
- View: `Admin::NotificationsController#show`

## Required Environment Variables

### FCM delivery

- `FIREBASE_PROJECT_ID`
- `APP_URL`

### Web push registration in the browser

- `FIREBASE_PROJECT_ID`
- `FIREBASE_API_KEY`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`
- `FIREBASE_WEB_VAPID_KEY`

### Optional

- `ADMIN_NOTIFICATION_API_TOKEN`
  Use this when you want to call admin notification endpoints without a Rails login session.
- `PUSH_NOTIFICATION_LINK`
  Defaults to `/loyalty`. This is the page opened when a notification is clicked.
- `FIREBASE_SERVICE_ACCOUNT_JSON`
  Optional. Locally, you can provide the full service account JSON as an env var. On Cloud Run, prefer Application Default Credentials from the service identity instead.
- `FIREBASE_AUTH_DOMAIN`
  Passed through to the browser Firebase config when present.
- `FIREBASE_STORAGE_BUCKET`
  Passed through to the browser Firebase config when present.
- `FIREBASE_MEASUREMENT_ID`
  Passed through to the browser Firebase config when present.

## Cloud Run Setup

### Recommended

Use the Cloud Run service identity for server-to-server FCM calls:

1. Create or choose a Google service account for the Cloud Run service.
2. Grant it Firebase Cloud Messaging send access for the target Firebase project.
3. Deploy the service with that runtime service account.
4. Set the web-push env vars listed above.

### Local or non-ADC fallback

If you are not using Cloud Run service identity, set `FIREBASE_SERVICE_ACCOUNT_JSON` with the Firebase service account JSON contents.

## Google Cloud Console Runbook

This is the console workflow used for the current deployment shape:

- Firebase / FCM project: `fuel loyalty`
- Cloud Run project: `thoughtbasics`
- Cloud Run service: `fuel-loyalty-git`
- Cloud Run migrate job: `fuel-loyalty-git-migrate`
- Runtime service account: `fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`

### 1. Create the runtime service account in `thoughtbasics`

In Google Cloud Console:

1. Switch to project `thoughtbasics`.
2. Open `IAM & Admin` -> `Service Accounts`.
3. Click `Create service account`.
4. Create:
   - name: `fuel-loyalty-push-runtime`
   - email: `fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`
5. Do not create or download a JSON key.

This service account is the Cloud Run runtime identity used for server-side FCM HTTP v1 calls via Application Default Credentials.

### 2. Allow Cloud Build to attach the runtime service account

In `thoughtbasics`, on the runtime service account:

1. Open `IAM & Admin` -> `Service Accounts`.
2. Click `fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`.
3. Open `Principals with access`.
4. Click `Grant access`.
5. Add principal:
   - `534102618638-compute@developer.gserviceaccount.com`
6. Grant role:
   - `Service Account User`

This was the principal selected from the console suggestions during setup. If a future Cloud Build trigger uses a different execution identity, grant the same role to that exact principal as well.

### 3. Grant FCM permissions in the Firebase project

In project `fuel loyalty`:

1. Open `IAM`.
2. Click `Grant access`.
3. New principal:
   - `fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`
4. Grant role:
   - `Firebase Cloud Messaging API Admin`

This is the cross-project permission that allows the Cloud Run runtime in `thoughtbasics` to send notifications for the Firebase project in `fuel loyalty`.

### 4. Collect Firebase web config values in `fuel loyalty`

In Firebase Console for `fuel loyalty`:

1. Open `Project settings`.
2. Open the registered Web app.
3. Copy:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_API_KEY`
   - `FIREBASE_AUTH_DOMAIN`
   - `FIREBASE_STORAGE_BUCKET` if present
   - `FIREBASE_MESSAGING_SENDER_ID`
   - `FIREBASE_APP_ID`
   - `FIREBASE_MEASUREMENT_ID` if present
4. Open `Cloud Messaging`.
5. Copy the Web Push VAPID key:
   - `FIREBASE_WEB_VAPID_KEY`

### 5. Configure the Cloud Run service in `thoughtbasics`

For service `fuel-loyalty-git`:

1. Open `Cloud Run`.
2. Open service `fuel-loyalty-git`.
3. Click `Edit and deploy new revision`.
4. In `Security`, select service account:
   - `fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`
5. In `Variables & Secrets`, set:
   - `APP_URL=https://fly.thoughtbasics.com`
   - `FIREBASE_PROJECT_ID=...`
   - `FIREBASE_API_KEY=...`
   - `FIREBASE_AUTH_DOMAIN=...`
   - `FIREBASE_STORAGE_BUCKET=...` if used
   - `FIREBASE_MESSAGING_SENDER_ID=...`
   - `FIREBASE_APP_ID=...`
   - `FIREBASE_MEASUREMENT_ID=...` if used
   - `FIREBASE_WEB_VAPID_KEY=...`
   - `ADMIN_NOTIFICATION_API_TOKEN=...` if using bearer auth
   - `PUSH_NOTIFICATION_LINK=/loyalty` if overriding the default
6. Deploy the revision.

### 6. Configure the Cloud Run migrate job in `thoughtbasics`

For job `fuel-loyalty-git-migrate`:

1. Open `Cloud Run` -> `Jobs`.
2. Open `fuel-loyalty-git-migrate`.
3. Click `Edit`.
4. In `Security`, select:
   - `fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`
5. In `Variables & Secrets`, set the same Firebase and app variables as the service.
6. Save or deploy the job update.

### 7. Keep the pipeline aligned

The deploy pipeline in `cloudbuild.yaml` is configured to use:

- service account substitution:
  - `_RUNTIME_SERVICE_ACCOUNT: fuel-loyalty-push-runtime@thoughtbasics.iam.gserviceaccount.com`

Both the Cloud Run service update and the migrate job deploy in the build pipeline should continue to use that runtime identity.

### 8. Smoke test after deploy

After deployment:

1. Open `https://fly.thoughtbasics.com` on a real device.
2. Allow notifications.
3. Confirm a row is created in `push_subscriptions`.
4. Open the admin Notifications page.
5. Send a test push notification.
6. Create a schedule.
7. Click `Run Scheduler`.

If push registration works but sending fails, the first thing to re-check is the `Firebase Cloud Messaging API Admin` grant in project `fuel loyalty`.

## Mapping the Firebase Console Snippet

If Firebase gives you a web config like this:

```js
const firebaseConfig = {
  apiKey: "...",
  authDomain: "fuel-loyalty.firebaseapp.com",
  projectId: "fuel-loyalty",
  storageBucket: "fuel-loyalty.firebasestorage.app",
  messagingSenderId: "629935221011",
  appId: "1:629935221011:web:...",
  measurementId: "G-..."
};
```

set the Rails environment variables like this:

```bash
FIREBASE_API_KEY=AIzaSyD2GOiEjnrGWDPQt1chym04qtmQ3F5LCEQ
FIREBASE_AUTH_DOMAIN=fuel-loyalty.firebaseapp.com
FIREBASE_PROJECT_ID=fuel-loyalty
FIREBASE_STORAGE_BUCKET=fuel-loyalty.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=629935221011
FIREBASE_APP_ID=1:629935221011:web:612bdd301126b28e8492e6
FIREBASE_MEASUREMENT_ID=G-K2Q0927ZJX
FIREBASE_WEB_VAPID_KEY=BM7ZYF-Ye-YL6sc9q7Te0wPoB_QMeTKrg_FCS6zoESZnK-3m8hRcT333tC-gC17dx3Yzfo5B-4XYU-NE1WIsVoE
```

`FIREBASE_WEB_VAPID_KEY` comes from Cloud Messaging Web Push certificates, not from the generated web app config snippet.
For this project, the current public VAPID key is `BM7ZYF-Ye-YL6sc9q7Te0wPoB_QMeTKrg_FCS6zoESZnK-3m8hRcT333tC-gC17dx3Yzfo5B-4XYU-NE1WIsVoE`.

## Example Requests

### Register a device token

```bash
curl -X POST https://your-app.example/push/subscriptions \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: <csrf-token>" \
  -d '{
    "token": "fcm-device-token",
    "platform": "android"
  }'
```

### Send a notification with bearer auth

```bash
curl -X POST https://your-app.example/admin/notifications/send \
  -H "Authorization: Bearer $ADMIN_NOTIFICATION_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Station update",
    "message": "Double points are live today."
  }'
```

### Create a daily schedule

```bash
curl -X POST https://your-app.example/admin/schedules \
  -H "Authorization: Bearer $ADMIN_NOTIFICATION_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Morning offer",
    "message": "Open the app for today'\''s loyalty offer.",
    "frequency": "daily",
    "scheduled_time": "09:00",
    "active": true
  }'
```

### Create a weekly schedule

```bash
curl -X POST https://your-app.example/admin/schedules \
  -H "Authorization: Bearer $ADMIN_NOTIFICATION_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Weekend promo",
    "message": "Weekend rewards are now active.",
    "frequency": "weekly",
    "scheduled_time": "08:30",
    "day_of_week": 6,
    "active": true
  }'
```

### Run the scheduler manually

```bash
curl -X POST https://your-app.example/admin/schedules/run \
  -H "Authorization: Bearer $ADMIN_NOTIFICATION_API_TOKEN"
```

## Scheduler Rules

`NotificationScheduleRunner.is_due?(schedule, current_time)` supports:

- `once`
  Requires `scheduled_date` and sends only one time.
- `daily`
  Sends once per day after `scheduled_time`.
- `weekly`
  Requires `day_of_week` and sends once after that weekday/time in the current week.
- `monthly`
  Requires `day_of_month` and sends once after that day/time in the current month.

If a monthly schedule is set to day `31`, shorter months send on that month's last day.

## Invalid Token Cleanup

`FirebasePushService` marks subscriptions inactive when FCM returns a token-specific error such as `UNREGISTERED` or `INVALID_ARGUMENT` from the FCM error details payload.

## Batching

FCM HTTP v1 targets a single token per message send. In this app, batching means:

- active subscriptions are processed in slices of up to `500`
- each slice reuses one HTTPS connection
- a small delay is inserted between slices

That keeps broadcasts predictable on Cloud Run without introducing background workers.

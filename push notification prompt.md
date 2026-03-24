You are a senior Ruby on Rails architect with deep expertise in PWAs, Firebase Cloud Messaging (FCM), and Google Cloud Run.

Build a production-ready push notification system for a Ruby on Rails PWA application deployed on Google Cloud Run.

Context:
- The application is a PWA with service workers already configured.
- Push notifications must work on mobile devices using Firebase Cloud Messaging (FCM).
- The backend is Ruby on Rails (full-stack).
- Deployment target is Google Cloud Run .
- The system must be low-cost (preferably zero-cost, no always-running workers).

Core Requirements:

1. Device Subscription Management
- Implement API to register and store FCM tokens.
- Store tokens in a database table (ActiveRecord model).
- Include fields: token, platform, last_used_at, active.
- Handle duplicate tokens and updates.

2. Manual Notification Trigger
- Create a secure POST endpoint:
  POST /admin/notifications/send
- Accept payload:
  {
    "title": "string",
    "message": "string"
  }
- Send push notifications to all active tokens using FCM.
- Use batch sending (max 500 tokens per request).

3. Custom Scheduler (UI-driven, NOT cron-based)
- Create a NotificationSchedule model with fields:
  - title
  - message
  - frequency (once, daily, weekly)
  - scheduled_time (HH:mm)
  - last_sent_at
  - active (boolean)

- Create API endpoints:
  POST /admin/schedules
  GET /admin/schedules
  POST /admin/schedules/run

- Implement logic:
  - “run scheduler” endpoint checks all schedules
  - determines which ones are due
  - sends notifications accordingly
  - updates last_sent_at

- DO NOT use background jobs or cron workers.
- This must work in a stateless Cloud Run environment.

4. Scheduler Execution Logic
- Implement helper:
  is_due?(schedule, current_time)
- Support:
  - once → send only once
  - daily → once per day at given time
  - weekly → once per week (assume day field if needed)
  - Monthly → once per month (assume day field if needed)

5. Firebase Integration
- Use FCM HTTP v1 API.
- Show how to authenticate using service account JSON.
- Implement Ruby service class:
  FirebasePushService

- Handle:
  - batching (<=500 tokens)
  - error handling
  - invalid token cleanup (mark inactive)

(Important: FCM does not support native scheduling, so scheduling must be implemented server-side) :contentReference[oaicite:0]{index=0}

6. Admin Security
- Protect admin endpoints using:
  - Bearer token OR Rails authentication
- Show example middleware or before_action.

7. Minimal Admin UI (Optional but preferred)
- Simple Rails view or JSON-based UI
- Form:
  - title
  - message
  - frequency
  - time
- Button:
  - “Send Now”
  - “Run Scheduler”
- Manage schedules (list, edit, delete)

8. Performance Considerations
- Use batching
- Avoid sending all tokens in one loop
- Add small delay between batches if needed

9. Deployment
- Ensure compatibility with Google Cloud Run:
  - stateless
  - no background workers
- Include:
  - Dockerfile
  - environment variable setup
  - secrets handling for Firebase credentials

10. Output Format
Provide:
- Architecture overview
- Rails models (ActiveRecord)
- Controllers
- Service classes
- Routes
- Example requests
- Firebase integration code
- Scheduler logic
- Deployment steps

Constraints:
- Keep system simple and cost-efficient
- Avoid Sidekiq, Redis, or cron jobs
- Must work fully with manual triggers + on-demand scheduler execution
- Code should be clean, production-ready, and idiomatic Rails

Goal:
Build a scalable but minimal notification system that supports:
- manual sending
- UI-based scheduling
- zero/low infrastructure cost
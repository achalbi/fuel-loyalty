# Ace Fuel Loyalty — Native Mobile App Rebuild Handoff

This folder is a complete, replication-grade specification of the Fuel Loyalty PWA, written so a team can rebuild it as a native mobile app (with a new or reused backend) without reading the Rails codebase.

**Source of truth:** Rails 8.1 app, schema version `2026_04_03_101500`, verified against code on 2026-07-12.

## Documents

| File | Contents |
|---|---|
| [01-overview-architecture.md](01-overview-architecture.md) | Product summary, tech stack, roles, app shells, navigation, global conventions |
| [02-data-model.md](02-data-model.md) | Every table, column, enum, validation, normalization rule, and dormant schema |
| [03-auth-roles-permissions.md](03-auth-roles-permissions.md) | Login, session rules, soft delete, full permission matrix |
| [04-business-logic.md](04-business-logic.md) | Points earn/redeem math, transaction creation, lookup tokens, attendance/shift algorithms |
| [05-feature-public-loyalty.md](05-feature-public-loyalty.md) | Customer-facing loyalty lookup (the only public surface), i18n, result page |
| [06-feature-staff.md](06-feature-staff.md) | New transaction wizard, redemptions, customer management, My Pump, notifications, password |
| [07-feature-admin.md](07-feature-admin.md) | Dashboard/analytics, users, staff/shifts/cycles/attendance, catalogs, reward rates, theme, customers, adjustments, transactions |
| [08-notifications-push.md](08-notifications-push.md) | FCM pipeline, schedules, scheduler lease, native push mapping |
| [09-plate-scanner.md](09-plate-scanner.md) | Camera capture, server recognition, OCR fallback, plate normalization |
| [10-pwa-platform-native-mapping.md](10-pwa-platform-native-mapping.md) | Service worker/offline/install/theming/analytics → native equivalents |
| [11-api-contracts.md](11-api-contracts.md) | Every endpoint: method, params, responses, JSON shapes |
| [12-dormant-gotchas-security.md](12-dormant-gotchas-security.md) | Dead schema, known gaps, env vars, secrets to rotate |

## How to use this handoff

1. Read 01–04 first — they define the domain and every business rule.
2. Build the backend from 02 + 04 + 11 (the API contracts assume the same business rules).
3. Build screens from 05–07; each screen lists fields, validations, exact copy, and flows.
4. Use 08–10 for platform integrations (push, camera, theming, offline).
5. Check 12 before launch — it lists what NOT to replicate and secrets to rotate.

## App identity

- Name: **Ace Fuel Loyalty**
- Purpose: fuel-station loyalty program (India). Customers earn points on fuel purchases, redeem for cash rewards. Staff record transactions and redemptions. Admins manage catalogs, rewards, staff shifts/attendance, analytics, and push notifications.
- Locale/timezone: India — `+91` phone numbers, ₹ currency, IST (`Asia/Kolkata`), Indian vehicle plate formats. Public loyalty pages localized in 11 languages (en, hi, kn, ta, te, ml, or, bn, mr, gu, pa).
- Default brand color: `#43B05C` (admin-configurable).

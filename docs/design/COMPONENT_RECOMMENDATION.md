# UI components & theme — recommendation

**For:** the native Android app (`android/`, Compose + Material 3)
**Date:** 13 July 2026
**Companion artifacts:** `docs/design/prototype/index.html` (clickable), `ui/designsystem/*.kt` (new components)

---

## The headline

**Don't pick a new component library or a new theme.** You already have the right answer: Material 3 + the Nayara token set (`design-tokens.json` → `NayaraColor.kt` / `NayaraTheme.kt`). It's brand-derived, contrast-verified, dark-mode complete, and correctly overrides M3's baseline purple-tinted surface containers — which is the mistake most M3 apps ship with.

The gap isn't the theme. It's **coverage and enforcement**: half the components the `DESIGN_BRIEF` specifies don't exist, so screens hand-roll them, and the app's information architecture doesn't match the brief at all.

Three things are worth changing. Everything else is filling in the gaps.

---

## 1. Foundation: keep Material 3, don't switch

| Option | Verdict |
|---|---|
| **Material 3 + Nayara tokens** (current) | ✅ **Keep.** M3 gives you the accessibility, RTL, dynamic-type and TalkBack behaviour for free. The token layer already sits on top of it cleanly via `LocalNayaraColors`. |
| Compose Material (M2) | ❌ Regression. |
| A third-party kit (Mirage/Carbon/etc.) | ❌ You'd be re-solving what `NayaraTheme.kt` already solves, and inherit someone else's brand assumptions. |
| Full custom design system | ❌ Only justified when M3's *behaviour* is wrong. It isn't — only its default *colors* were, and that's already fixed. |

**The pattern to hold onto:** M3 slots for structure and behaviour (`Button`, `NavigationBar`, `ModalBottomSheet`, `TextField`), `MaterialTheme.nayara.*` for every color. No `Color(0xFF…)` outside `NayaraColor.kt`. That rule is already in the brief's anti-patterns list — it just needs a lint rule to be real.

---

## 2. Theme fixes worth making

### 2.1 Manrope — fixed while this was being written ✅

When I started this audit, `res/font/manrope_variable.ttf` was bundled but **no Kotlin referenced it** — `NayaraTypography` declared the scale and never set a `fontFamily`, so every screen silently fell back to Roboto.

That's now closed: `ui/theme/NayaraFont.kt` pins each weight on the variable font's `wght` axis, and `NayaraTypography` applies `fontFamily = Manrope` across the scale. Nothing more to do. I removed my own duplicate of this file.

**One thing to watch.** Manrope is now applied to `bodyLarge`/`bodyMedium`/`labelSmall` too — every role. Manrope has **zero Indic coverage**, and the app ships 11 locales (hi, kn, ta, te, ml, or, bn, mr, gu, pa). Compose will fall back per-glyph, so nothing breaks, but Hindi and Kannada body text will render in a different face than the Latin around it, and the weight will not match. Consider keeping display/headline/title on Manrope and letting body/label resolve to the platform face, which carries the Noto chain natively. That's a one-line change and it's why the split is worth making deliberately rather than by accident.

### 2.2 Web and native disagree on typeface

Web ships **Poppins** (Latin + Devanagari webfonts in `app/assets/stylesheets`); the token spec and the native font asset say **Manrope**. Pick one. My recommendation is Manrope everywhere — better tabular figures at hero sizes, which matters more here than anywhere because *numbers are the interface*. Migrating web is a one-line `@font-face` change plus dropping the Poppins files.

### 2.3 The admin brand seed can silently break contrast

`theme_setting.primary_color` is a free-text hex. `BrandPalette` derives a contrast color by brightness (`(R*299 + G*587 + B*114)/1000 >= 150 ? navy-950 : white`), which is a reasonable heuristic — but **nothing stops an admin picking a color that fails AA against white**, and the derived `primaryContainer`/`primaryHover` ramp isn't checked at all.

Two options, in order of preference:

1. **Constrain the picker** to a preset ramp (the 5 brand anchors + a few neutrals). This is what the prototype's swatch picker demonstrates. Loses nothing anyone actually wants.
2. **Validate server-side** in `ThemeSetting` — reject a hex whose derived pairs fall below 4.5:1.

Right now a well-meaning admin can make the whole app unreadable and no code path objects.

---

## 3. Component inventory

### Already shipped (`ui/designsystem/`) — 14 components, good ones

`AnimatedCounter` · `Avatar` · `StatusChip` / `ActiveChip` / `PlateChip` / `PointsPill` · `ConfirmDialog` · `NayaraSnackbarHost` · `FormField` / `PasswordField` / `PickerField` · `rememberHaptics` · `DateField` / `TimeField` · `NayaraPullToRefresh` · `SearchField` · `Skeleton*` (7 variants) · `ErrorState` / `EmptyState` / `InlineErrorCard` · `SuccessOverlay` · `NayaraTopBar`
Plus in `ui/theme/`: `NayaraButton` / `NayaraTonalButton` / `NayaraOutlinedButton` / `NayaraHeroCard`.

`AnimatedCounter` in particular is better than it needs to be — per-digit rolling with correct direction on decrease. Don't touch it.

### New in this pass — 15 components

| Component | File | Why it exists |
|---|---|---|
| `NayaraBottomBar` + `NayaraScanFab` | `BottomNav.kt` | **The IA gap.** See §4. |
| `NayaraActionBar` | `BottomNav.kt` | Sticky bottom primary action (customer profile). |
| `NayaraKeypad` | `Keypad.kt` | Amount entry without an IME. |
| `NayaraAmountDisplay` | `Keypad.kt` | 44sp hero read-out, ₹ in `text.tertiary`. |
| `NayaraConversionLine` | `Keypad.kt` | Shows `PointsCalculator`'s rule at the point of entry. |
| `NayaraPointsStepper` | `Keypad.kt` | Makes an invalid redemption **unrepresentable**. See §5. |
| `SectionHeader` | `Cards.kt` | — |
| `MetricCard` | `Cards.kt` | The admin dashboard API already returns `direction` + `change_pct`; nothing rendered it consistently. |
| `QuickAction` | `Cards.kt` | Home action grid. |
| `RewardCard` | `Cards.kt` | Locked state stays tappable and says *how short*. |
| `NayaraProgress` | `Cards.kt` | Tier bar; gold sheen reserved for Gold-adjacent. |
| `LedgerRow` + `DayHeader` + `NayaraListRow` | `LedgerRow.kt` | One row anatomy, three placements. Includes the offline-queue state. |
| `NayaraSegmentedControl` | `Controls.kt` | Plate / Phone / Card lookup mode; ₹ / litres toggle. |
| `TierBadge` · `NayaraBanner` · `HoldToConfirmButton` · `IconCircle` · `FuelDot` | `Controls.kt` | See §5, §6. |
| `NayaraBottomSheet` | `Sheets.kt` | 28dp top radius, 36×4 handle, `overlay.scrim`. |

---

## 4. The information architecture — now wired ✅

Navigation used to be menu-card driven from `HomeScreen`, which buried the app's highest-frequency action — scan plate → resolve customer → award — two taps deep behind a scroll. For an attendant holding a phone one-handed at a pump, that action *is* the product.

**Shipped:**

```
[ Home ]   [ Customers ]   ( SCAN ▣ )   [ Redeem ]   [ Account ]
```

- `ui/designsystem/BottomNav.kt` — `NayaraBottomBar`, `NayaraScanFab`, `NayaraActionBar`
- `ui/AppRoot.kt` — `Scaffold` + bottom bar, shown only when signed in and only on the four tab routes. Tab switching uses `popUpTo(HOME) { saveState }` + `launchSingleTop` + `restoreState`, so the stack stays shallow and each tab keeps its scroll position.
- `ui/account/AccountScreen.kt` — new fourth destination (identity, admin entry, log out). Log out moved off Home; Home is for doing work, not leaving.

**Why Redeem and not Activity.** The brief's fourth tab is Activity. It isn't there because it *can't* be: there is **no staff-scoped transactions endpoint**. `AceFuelApi` exposes only `GET /api/v1/staff/customers/:id/ledger` (one customer at a time) and `GET /api/v1/admin/transactions` (admin-only). A staff activity feed needs a new server route first. Redeem takes the slot meanwhile — it's the second-most-used action and earns its place. The prototype still shows the Activity screen as the target design for when the endpoint exists.

**Two implementation notes worth keeping.**

The FAB **must live inside the parent's bounds.** A FAB placed with a negative `offset` renders correctly and then silently drops every touch that falls outside the parent — a bug that passes visual review and dies on the forecourt. `NayaraBottomBar` uses a 20dp transparent gutter above the bar instead.

The scan FAB pushes `new_transaction` *then* `plate_scanner`. `PlateScannerScreen` writes its result to `previousBackStackEntry`, so the transaction screen has to be the thing sitting underneath it — otherwise the scanned plate lands on Home and vanishes.

---

## 5. Make invalid states unrepresentable, not reportable

Two backend rules are currently enforced *after* the attendant commits, as 422 errors:

**`PointsRedeemer`** rejects anything that isn't a positive multiple of `redemption_increment`, at least `minimum_redeemable_points`, at most `max_redeemable_points`.
→ `NayaraPointsStepper` locks the value to the increment and clamps to the range. **The error can't happen.**

**Redemption is irreversible** — it writes a negative ledger row and there is no undo endpoint. On a wet forecourt phone, a mis-tap is a support ticket and an angry customer.
→ `HoldToConfirmButton` costs 700ms and removes the entire class.

Same reasoning applies to plate OCR. `VehiclePlateRecognizer` already returns up to 3 candidates with confidence and a `corrected: true` flag when it applied a substitution — **and no UI surfaces any of it.** The scan flow should never auto-commit a guess: show the read-out big, show the confidence, offer the alternates as chips, keep a manual-entry escape hatch. That's the `staff-scan` screen in the prototype.

---

## 6. Two rules the components now enforce for you

**Earn must not look like spend.** `LedgerRow` only paints green for `entry_type: earn`. A *positive adjustment* is a correction, not a reward — it stays neutral. Redeem gets navy/gold and a confirmation ceremony; earn gets green, upward motion and `celebrateSpring`. Never celebrate a subtractive event.

**No shadows in dark mode.** The token set sets every shadow to `none` in dark and separates surfaces with 1dp borders — in dark, M3 elevation reads as a muddy grey wash.

`NayaraCard` currently applies a flat `2.dp` elevation in **both** modes, so dark screens are getting a shadow the tokens explicitly say shouldn't exist. Worth folding the branch into `NayaraCard` itself (elevation in light, `BorderStroke(1.dp, border.default)` in dark) so no screen has to remember. One component, one place.

---

## 7. Per-persona recommendation

| Persona | Recommendation |
|---|---|
| **Staff** | The core of the native app. Everything above is aimed here. Ship the tab bar + FAB, the keypad sheet, and the redeem gate — those three change the daily experience more than anything else on the list. |
| **Customer / member** | **Doesn't exist yet.** The only customer surface is an anonymous public phone lookup. A real member app needs new backend work first: customer authentication (OTP), a stations/prices endpoint, and a `tier` concept (there is **no tier column** — it's UI-invented today; derive it in one place or add it to the serializer before two clients invent different thresholds). Prototyped so you can see the shape of it, but scope this honestly. |
| **Admin** | My honest read: **native buys you least here.** Keep the dashboard in-app for glanceability — `MetricCard` + a chart card is enough. But shift cycles, attendance rosters, catalog CRUD and reward-rate matrices are dense, low-frequency, keyboard-friendly configuration. That's web work. You already have 13 admin screens in Compose; I wouldn't build more, and I'd resist the pull to reach parity. |

---

## 8. Suggested order

1. ~~Wire up Manrope~~ — **done** (see §2.1).
2. ~~`NayaraBottomBar` + `Scaffold` in `AppRoot`~~ — **done** (see §4).
3. **Award keypad sheet** (`NayaraKeypad` + `NayaraConversionLine`). The hottest path.
4. **Redeem stepper + hold-to-confirm.** Removes a whole error class.
5. **Plate-confirm step.** Surfaces OCR data the server already sends and currently throws away.
6. **Fold the dark-mode border branch into `NayaraCard`** (§6), then migrate screens onto `NayaraCard` / `LedgerRow` / `MetricCard`. Gradual.
7. Add a **lint rule** banning `Color(0xFF…)` outside `NayaraColor.kt` so token discipline survives the next contributor.
8. Constrain the **admin brand-seed picker** to a preset ramp (§2.3).
9. *Then* decide about the member app — and answer the backend questions first.

---

## 9. Verification notes

- **Not compiled.** There's no Android SDK in my sandbox, so these files are statically checked, not built. I verified: no redeclarations against the existing design system, no unused imports, every referenced symbol (`NayaraCard`, `AnimatedCounter`, `PlateChip`, `rememberHaptics`, `NayaraNumerals`, `NayaraSpacing`, `NayaraMotion`, `NayaraPalette`) resolves, and no `Color(0xFF…)` literals. Run `./gradlew compileDebugKotlin` before trusting it.
- **The repo moved under me.** `NayaraCard.kt` and `NayaraFont.kt` were added *while* I was writing — my first drafts collided with both. I deleted my duplicate font file and rebuilt `Cards.kt` on the existing `NayaraCard`. If you're mid-edit, re-check for collisions before merging.
- **Prototype tokens verified** against `docs/design/tokens.css` — all 56 declared tokens match the source exactly.
- **Figma file pushed but not visually verified** — I hit the Starter-plan MCP call limit before I could screenshot it back. Worth an eyeball.

---

## Backend work the UI is now waiting on

| Need | Endpoint | Blocks |
|---|---|---|
| Staff activity feed | `GET /api/v1/staff/transactions` (doesn't exist) | The Activity tab. Redeem is holding its slot. |
| My Pump | `GET/PATCH /api/v1/my_pump` — **exists server-side, no Retrofit binding** | Staff can't see or change their own nozzle assignment in-app, which is the exact thing that blocks them recording a transaction. Cheapest high-value fix on this list. |
| Customer auth | OTP login (doesn't exist) | The whole member app. |
| Tier | no column on `customers` | `TierBadge` is currently UI-invented. |

---

## Open questions I couldn't resolve from the code

- **Tier thresholds.** Nothing in the schema defines them. Whoever owns the loyalty program needs to say what Gold means.
- **Reason codes for adjustments.** The brief asks for one; `points_ledgers` has no `reason` column. Adding it is a migration, and worth it — a manual adjustment with no audit trail is the thing you'll wish you had logged.
- **Offline writes.** `LedgerRow(pending = true)` renders a queued transaction, but there's no offline queue in the app and the service worker explicitly refuses to cache authenticated staff data. Is offline award actually in scope? If yes, it's a much bigger conversation than a component.

# Nayara Fuel-Loyalty — Native App Design Brief

> **How to use this file:** feed it, together with `design-tokens.json`, `compose/NayaraColor.kt`, and `compose/NayaraTheme.kt`, to the coding agent implementing UI. Every color, size, and motion value referenced here exists as a token. If a screen spec and a token conflict, the token wins. Never hardcode a hex.

---

## 1. Brand foundation (verified, not guessed)

Colors were pixel-extracted from the official Nayara Energy logo (3540×3024, Wikimedia Commons) and nayaraenergy.com:

| Anchor | Hex | Source | Role in app |
|---|---|---|---|
| Nayara Navy | `#10447C` | wordmark + lead ribbon | Brand ink. Headers, hero cards, light-mode primary ramp (`navy`) |
| Nayara Cyan | `#0080A0` | middle ribbon | Accent/secondary (`cyan`). Info, selected states, links’ ramp base |
| Nayara Green | `#18945C` | leaf ribbon | Success + “earn” moments (`green`). Points credited, petrol product color |
| Nayara Sky | `#249ADF` | nayaraenergy.com `theme-color` | Links, focus, dark-mode primary (`sky`) |
| Reward Gold | `#F5A524` | functional (non-brand) | Points, coins, Gold tier, offers (`amber`) |

The logo story — three ribbons flowing together (navy → cyan → green) — is the app’s signature gradient token `gradient.brandRibbon`. Use it **sparingly**: hero card top edge, splash, achievement moments. Never as body background.

Rules: navy is the voice, cyan is the energy, green is the reward, gold is the celebration. Red only for errors/destructive. No purple/magenta/orange anywhere — they are not Nayara.

## 2. Design principles

1. **Forecourt-first.** Staff use this in sunlight, one-handed, with wet or gloved hands. Min touch target 48dp, primary actions in thumb reach (bottom 40% of screen), AA contrast enforced (all 22 shipped pairs verified ≥4.5:1).
2. **Numbers are the interface.** Points, litres, ₹ — always tabular numerals (`NayaraNumerals`), always the biggest thing on the card. A balance should be readable at arm’s length: 44sp hero.
3. **One screen, one job.** Each screen has exactly one primary action rendered as the single filled button. Everything else is tonal/text.
4. **Earn feels different from spend.** Crediting points = green + upward motion + `celebrateSpring`. Redeeming = navy/gold + confirmation ceremony. Never the same animation for both.
5. **Calm chrome, vivid moments.** Surfaces are white/near-white (dark: navy-black `#080F18`), color arrives only through data and moments. Density stays low; whitespace is the luxury.

## 3. Benchmarks — what to steal from the world’s best

| App | Steal this | Applied here |
|---|---|---|
| **Starbucks** | Tier progress as a visible journey; bonus-challenge cards (“3 visits this week = 50 bonus stars”); balance always on home | Home balance card, tier ring, challenge rail |
| **CRED** | Redemption as ceremony (scratch cards, confetti, haptics); dark luxe surfaces; oversized numerals | Redeem success flow, dark mode surfaces, `NayaraNumerals.Hero` |
| **Shell Go+ / bp earnify** | Fuel-native flows: station finder, pay-at-pump, fuel-type color coding, receipts in-app | `fuel.petrol/diesel/premium` tokens, station sheet pattern |
| **Revolut / Monzo** | Animated count-up balances; transaction list with strong iconography; skeleton loaders not spinners | Points history list, count-up on credit |
| **PhonePe / Google Pay (India)** | Center scan action in nav; phone+OTP auth; UPI-grade success screens; bilingual readiness | Scan-plate FAB, login flow, success screen |
| **Uber** | Map + draggable bottom sheet as the finder pattern | Station/outlet finder (member app) |
| **Duolingo** | Streaks and gentle loss-aversion (“visit this week to keep your streak”) | Member app engagement loop |

## 4. Information architecture

### 4a. Staff app (current codebase: `ui/home`, `ui/customers`, `ui/loyalty`, `ui/redeem`, `ui/adjust`, `ui/login`)

Bottom navigation, 4 destinations + center action:

```
[ Home ]  [ Customers ]  ( SCAN ▣ )  [ Activity ]  [ Account ]
```

- **SCAN** — 64dp circular FAB, `gradient.brandRibbon` border ring, docked center. Opens plate-scanner (existing `vehicle-plate-scanner` flow) → resolves customer → action sheet: **Award / Redeem / Adjust**.
- Home = shift dashboard. Customers = search/browse. Activity = transaction log. Account = station, staff profile, theme.

### 4b. Member app (blueprint, when built)

```
[ Home ]  [ Stations ]  ( PAY/SCAN )  [ Rewards ]  [ Profile ]
```

## 5. Screen specs — staff app

### 5.1 Login (`ui/login`)
- Canvas `bg.canvas`; Nayara logo top-third; phone number field (`inputHeight` 52dp, radius `md` 14) with +91 prefix; primary button “Send OTP” (`buttonLg` 52dp, `action.primary`, radius `md`).
- OTP screen: 6 boxes 48×56dp, radius `sm`, auto-advance, `border.focus` on active box; resend as text button with 30s countdown in `text.tertiary`.
- Error: shake 3× (translationX ±8dp, `Fast` 140ms), field border `status.error`, message below in `status.errorText` 13sp. No toasts for auth errors.

### 5.2 Home — shift dashboard (`ui/home`)
Top → bottom:
1. **App bar:** station name (titleMedium) + staff avatar 32dp. Surface transparent over `bg.canvas`; elevate to `shadow.e1` + `bg.surface` after 8dp scroll (`Base` 220ms).
2. **Hero card** — `gradient.heroCard`, radius `lg` 18, padding `CardPadding` 20: “Today at your pump” label (labelMedium, white 70%); litres sold + points awarded as two `NayaraNumerals.Large` white columns; thin `gradient.brandRibbon` strip (3dp) across card top.
3. **Quick actions row** — 4 tonal cards (grid, `Gutter` 12): Award points, Redeem, Lookup, Adjust. Icon 24dp in `action.primaryContainer` circle 44dp, label 12sp. Press: scale 0.97 `pressSpring` + `overlay.pressed`.
4. **Recent activity** — last 8 transactions, `listRowLg` 72dp rows: leading icon (earn = arrow-up in `status.successContainer` circle / redeem = gift in `reward.pointsContainer` circle), customer masked phone + plate chip, trailing signed points in `NayaraNumerals.Default` (`+120` green-700 / `−500` neutral-950). Skeleton shimmer while loading, never spinners.

### 5.3 Customer lookup (`ui/loyalty`)
- Search field with segmented mode: **Plate / Phone / Card**. Plate mode shows scan icon → camera.
- Live results as cards: plate chip (mono 15sp, `bg.surfaceSunken`, radius `xs`), name, tier badge, points balance right-aligned `NayaraNumerals.Default`.
- Empty state: illustration-free — 48dp icon in `accent.container` circle, “No member found”, secondary button “Register new member”. Zero-result must render < 300ms with cached index.

### 5.4 Customer profile (`ui/customers`)
- Header: avatar/initials 56dp on `bg.brandSubtle` band; name headlineMedium; tier badge (`tier.gold` etc.) with subtle sheen only for Gold+.
- Balance card: points `NayaraNumerals.Hero`, “≈ ₹value” beneath in `text.secondary`; tier progress bar 8dp, track `border.subtle`, fill `gradient.goldShine` when Gold-adjacent otherwise `accent.default`; “1,240 pts to Gold” caption.
- Vehicles: horizontal chips of plates; add-vehicle ghost chip.
- Sticky bottom action bar (`bg.surface`, `shadow.e3`, safe-area padded): filled **Award points** + tonal **Redeem**.

### 5.5 Award / Adjust points (`ui/adjust`)
- Numeric keypad-first sheet (`extraLarge` 28 top radius): amount ₹ or litres toggle; live conversion line “₹2,000 → **240 pts**” (points in `status.successText`); fuel-type selector chips colored `fuel.petrol/diesel/premium` (selected = filled, unselected = outlined).
- Confirm → full-screen success: green tick draws in (path animation 320ms `Emphasized`), points count up 0→240 (`Slow` 480ms), single medium haptic, auto-dismiss 2.2s. Adjust (negative) uses navy styling and **requires reason code** — never celebrate a correction.

### 5.6 Redeem (`ui/redeem`)
- Balance pinned top in `reward.pointsContainer` pill (coin icon `reward.coin`).
- Reward catalog: 2-col grid cards (radius `lg`): value headline, points cost in `reward.pointsText`; insufficient = 40% desaturate + lock badge, card stays tappable to show “x pts short”.
- Redemption ceremony: hold-to-confirm button (fill sweeps `Gentle` 320ms) → success screen with confetti burst ≤1.2s in brand colors only (navy/cyan/green/gold), QR/code block `bg.surfaceSunken` radius `md`, “Show at counter” caption. Share/receipt actions as text buttons.

### 5.7 Activity log
- Grouped by day, sticky date headers (labelMedium `text.tertiary` uppercase).
- Filter chips: All / Awarded / Redeemed / Adjusted. Row anatomy identical to Home recent list (consistency > novelty).
- Offline queue badge: pending syncs shown with dashed border + `status.warning` dot; row resolves with a 220ms green flash on sync.

## 6. Member app blueprint (build-next)

- **Home:** greeting + tier ring (progress ring 10dp, `gradient.brandRibbon` stroke); balance hero with count-up; “Nearest Nayara pump — 1.2 km” card with fuel prices (petrol green / diesel navy / premium gold chips); challenge rail (Starbucks-style horizontal cards: “Fuel 3× this month → +500”); offers grid.
- **Stations:** full-bleed map, Uber-style draggable sheet (peek 96dp / half / full): station rows with distance, amenities icons, live fuel prices, “Navigate” tonal button.
- **Pay/Scan:** center action. QR pay at pump → amount → UPI handoff → success screen mirrors staff award ceremony (same tokens, same motion — the brand feels identical on both sides of the counter).
- **Rewards:** tier journey (Member → Silver → Gold → Platinum, `tier.*` tokens), scratch-card surprises post-fill (CRED pattern, max 1/day), redemption catalog + history.
- **Profile:** vehicles (plate chips), FASTag/fleet link, language switcher (English/हिन्दी/ગુજરાતી — Noto Sans fallback ships in tokens), notifications with granular toggles.

## 7. Component specs (both apps)

| Component | Spec |
|---|---|
| **Buttons** | Lg 52 / Md 44 / Sm 36dp; radius `md` 14; filled = `action.primary`, tonal = `action.secondary` + `action.onSecondary`, destructive = `status.error`; pressed scale 0.97 `pressSpring`; disabled `action.disabledBg`/`action.onDisabled`; loading = inline 20dp progress replacing label, width locked |
| **Cards** | radius `lg` 18, `bg.surface`, `shadow.e1` light / `border.default` 1dp dark (no shadows in dark), padding 20 |
| **Chips** | height 32, radius `full`, selected = `accent.container`+`accent.onContainer`, 1dp `border.default` unselected |
| **Inputs** | 52dp, radius `md`, `bg.surface`, 1dp `border.default` → 2dp `border.focus`; label floats 12sp; error border + helper `status.errorText` |
| **Bottom sheets** | top radius `xxl` 28, handle 36×4 `border.strong`, scrim `overlay.scrim`; enter `Emphasized` 320ms slide+fade |
| **Tab bar** | 64dp + insets, `bg.surface`, top `border.subtle`; active = icon filled + `action.primary` + 4dp dot; inactive `text.tertiary`; center FAB 64dp overlapping 12dp |
| **Snackbar** | `bg.inverse` + `text.inverse`, radius `md`, bottom-floating 16dp margins; only for undoable events |
| **Points pill** | `reward.pointsContainer` bg, coin 16dp `reward.coin`, value `NayaraNumerals.Default` in `reward.pointsText` |
| **Plate chip** | monospace 15sp, `bg.surfaceSunken`, radius `xs` 6, 1dp border — mimics an Indian number plate |
| **Skeletons** | `border.subtle` base, shimmer sweep 1.1s linear; match final layout exactly |

## 8. Motion system

- Durations/easings from tokens only: `Instant` 80 (state ticks) · `Fast` 140 (press feedback) · `Base` 220 (nav transitions, list items) · `Gentle` 320 (sheets, success draws) · `Slow` 480 (count-ups).
- Screen transitions: forward = slide-up 24dp + fade (`Enter`); back = fade only (`Exit`, 140ms). Shared-element the balance card Home → Profile.
- Count-up numerals on any balance change; never jump-cut a number the user cares about.
- Haptics: light tick on selection, medium on award success, double-light on redeem confirm. Never on error alone — pair with visual.
- Respect reduced-motion: replace springs/confetti with 140ms fades; keep count-ups but cap at 200ms.

## 9. Accessibility & localization

- WCAG 2.1 AA minimum; every shipped pair pre-verified (see `design-tokens.json` provenance). Focus visible always (`border.focus` 2dp).
- Dynamic type: layouts must survive 1.3× font scale; numerals may cap at 1.15×.
- All icons paired with text or contentDescription; plate/phone masked in a11y announcements.
- Strings externalized day one; Devanagari/Gujarati via Noto Sans fallback; numerals stay Latin tabular.

## 10. Anti-patterns (hard no)

- No pure black `#000` surfaces; dark canvas is `#080F18` (navy-tinted).
- No hardcoded hexes, no `Color(0xFF...)` outside `NayaraColor.kt`.
- No spinners where a skeleton fits; no toasts for errors that need action.
- No gradient text, no more than one gradient element per screen.
- No celebration on subtractive events (adjustments, expiry).
- No orange/purple/magenta — off-brand.

## 11. Integration notes (this codebase)

1. Copy `docs/design/compose/NayaraColor.kt` and `NayaraTheme.kt` into `android/app/src/main/kotlin/com/acefuel/loyalty/ui/theme/`.
2. Replace `AceFuelLoyaltyTheme { }` with `NayaraTheme { }` in `MainActivity`/`AppRoot`, or keep the admin-seed path by setting `BrandPalette.DEFAULT_HEX = "#10447C"` and mapping `strong/accent/soft` to `navy-900 / sky-300 / navy-50`.
3. Web (Rails views + `inapp` dashboard): link `docs/design/tokens.css`; existing CSS-variable math in `docs/native-handoff/10` should be retired in favor of the explicit `--*` semantic vars.
4. Bundle Manrope (weights 400/600/700/800) in `res/font`; wire into `NayaraTypography` font families.
5. `design-tokens.json` is Style-Dictionary-compatible (DTCG `$type`/`$value`) if you later automate iOS/web exports.

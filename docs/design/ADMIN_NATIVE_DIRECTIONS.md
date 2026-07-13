# Admin console — UI teardown & three native directions

Companion to `docs/design/prototype/admin-native.html` (open in a browser; every screen is tappable).
Tokens: `docs/design/tokens.css`. Feature source of truth: `docs/native-handoff/07-feature-admin.md`.

---

## 1. Can the admin console UI be improved?

Yes — and the interesting problems aren't cosmetic. The Bootstrap shell is competent: consistent cards, a real theme system, skeletons instead of spinners, chart panels that refetch without navigation. The issues are structural.

**1. It reports, it doesn't route.** The dashboard answers *"how are we doing?"* — eight KPIs, seven charts, two leaderboards. Nothing on it answers *"what needs me right now?"* An admin who opens the app because a shift closed unrecorded has to already know to go look. Every actionable state in the system (attendance window unrecorded, schedule failed delivery, nozzle inactive, staff unassigned, last-admin guard tripped) is invisible until you navigate to the page that owns it.

**2. The sidebar has 15 destinations in 4 unlabelled-by-frequency groups.** Reward Rates, Fuel Types, Vehicle Types, Pumps and Theme are *configured once and touched twice a year*. They sit at the same visual weight as Customers and Transactions, which are daily. The nav is an inventory of the codebase, not a model of the job.

**3. Density is web-density.** 72px rows, 20px card padding, 8 KPI cards in a grid — fine at 1440px, punishing at 390px. The dashboard toolbar alone (quick-range chips + two date fields + segment select + fuel chips + Reset + Download PDF) is roughly a full phone screen before a single number appears.

**4. Destructive and irreversible actions look like ordinary ones.** Attendance entries are immutable after save; transactions are never editable; soft-delete is the only delete. The UI doesn't telegraph any of that until you hit a confirm modal.

**5. Two apps, one brand, two feels.** `DESIGN_BRIEF.md` specs a bottom-nav, FAB-centred, gradient-hero staff app. The admin console is a desktop sidebar app. An admin uses *both*. Right now they don't feel like the same product.

**Small wins available immediately on the existing web console**, independent of any native work: collapse config into a single "Settings" group; add an alert strip above the KPI grid; move Download PDF out of the filter form; make the 8 KPI cards a 4-up with the rest behind "All 8".

---

## 2. The three directions

All three use identical data, identical tokens, and the same three deep screens (Customer profile, Record attendance, plus their home). They differ on one question: **what is the admin app *for* in the 40 seconds someone actually opens it?**

### Option A — Console
*The web console, made thumb-native.*

Home is the analytics overview: gradient hero, swipeable KPI rail, charts. Four tabs (Overview · Customers · Ops · Settings) that map to the sidebar's existing groups.

- **For:** zero re-training, fastest to ship, one-to-one with `07-feature-admin.md`, easiest to keep in sync with the web.
- **Against:** faithfully reproduces the core flaw — it still reports and doesn't route. The most urgent thing in the system (an unrecorded shift) is three taps deep on a tab called "Ops".
- **Ship if:** the priority is parity and speed, and admins are already sitting at a desk anyway.

### Option B — Signal  ← recommended
*Triage first. Numbers on demand.*

Home is a **"Needs you today" feed**: unrecorded attendance, failed/pending notification schedules, inactive nozzles, unassigned staff — each card carrying its own one-tap fix and its own severity colour. Analytics gets its own tab. A centre FAB (Adjust · Redeem · Record attendance · Send · Look up) mirrors the staff app's SCAN FAB, so the two apps read as one product.

- **For:** matches how a phone is actually used — standing up, deciding something. Turns the admin app from a dashboard into an operating tool. Resolves the brand split with the staff app for free.
- **Against:** needs an **alert rules layer** that doesn't exist yet — roughly a `GET /api/v1/admin/attention` endpoint deriving states the DB already knows (open attendance windows, `NotificationSchedule#last_sent_at`, inactive `FuelPumpNozzle`, staff with no current `ShiftAssignment`). That's a real but bounded backend addition.
- **Ship if:** the admin is an owner-operator with a phone in their hand, which is the actual user.

### Option C — Palette
*Search is the navigation.*

No tab bar. A single scroll of **reorderable widgets** and one persistent command bar. Type `att` → Record Attendance; type a plate → the customer; type `rew` → Reward Rates. All 15 sections become searchable rather than navigable.

- **For:** the only option that doesn't get worse as sections are added — the IA stops fighting the 5-tab ceiling. Power-user speed once learned. Widget home means each admin sees their own console.
- **Against:** discoverability. A once-a-quarter admin who doesn't remember that "Vehicle Types" exists will never search for it. Highest build cost (search index, widget persistence, command registry) and the only one that needs real user education.
- **Ship if:** the admin base is small, expert, and the section count is going to keep growing.

---

## 3. Recommendation

**Option B**, with two borrowings:

- Take Option A's KPI rail wholesale for the Insights tab — that work is already specced and correct.
- Take Option C's command bar and add it to B's search field later, as an accelerator rather than as the navigation. It's additive; it doesn't need to be in v1.

The single highest-value thing in any of these prototypes is the **attention feed**. It's the one idea that changes what the product *does* rather than how it looks, and it's the one thing the current console structurally cannot express.

---

## 4. What still needs deciding

- **The alert rules.** Which states are urgent enough to interrupt? My draft: unrecorded attendance window (critical), schedule delivery failure > 5% (critical), inactive nozzle with 0 fills in N days (warning), staff active but unassigned (warning), schedule firing within 3h (info).
- **Do admins get the staff screens too?** Today they do (`07`: "Admins also use all staff screens"). If the native admin app ships without New Transaction / Redeem, an admin covering a counter has to switch apps.
- **Offline.** The service worker denylists everything under `/admin`. Does the native app hold the same line, or cache the last dashboard payload with a "last updated" stamp?

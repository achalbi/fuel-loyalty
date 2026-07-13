# Play Console listing & App-content checklist

App: **Ace Fuel Loyalty** · package `com.acefuel.loyalty`

URLs to paste into the Console:
- Privacy policy: `https://fly.thoughtbasics.com/privacy`
- Account/data deletion: `https://fly.thoughtbasics.com/delete-account`

Answers below are derived from the actual app code (see reasoning in the repo/PR).
Key facts: only Camera + Internet + Notifications permissions; **plate scanning is
on-device (ML Kit) — images are never uploaded**; no analytics SDK (FCM only); all
traffic is HTTPS.

---

## Policy → App content

### Privacy policy
- [ ] URL: `https://fly.thoughtbasics.com/privacy`

### Data deletion
- [ ] Provide the deletion URL: `https://fly.thoughtbasics.com/delete-account`
- [ ] "How can users request that their data is deleted?" → **Web URL** (above)

### Ads
- [ ] "Does your app contain ads?" → **No**

### Data safety
- [ ] "Does your app collect or share any of the required user data types?" → **Yes**

**Data collected** — for each: purpose = *App functionality* (add *Account management*
where noted); **collected**, **not shared**; **encrypted in transit = Yes**; not
processed ephemerally; not optional:

| Category | Type | Notes |
|---|---|---|
| Personal info | Name | customer names |
| Personal info | Email address | customer email |
| Personal info | Phone number | customer phone (also cached on device) |
| Personal info | User IDs | staff login + customer IDs |
| Financial info | Purchase history | loyalty points / transactions — *include if you treat fuel-purchase→points as a purchase record* |
| Device or other IDs | Device or other IDs | FCM push token |

**Mark NOT collected:** Location · Photos/Videos · Files & docs · Contacts · Calendar ·
Messages · Audio · Health & fitness · Web browsing history · App activity / analytics.

- [ ] Sharing with third parties → **No** (data goes only to our backend; FCM is a service provider, not "sharing")
- [ ] Encrypted in transit → **Yes**
- [ ] Users can request data deletion → **Yes** (deletion URL above)

### Content rating (IARC questionnaire)
- [ ] Email for the rating certificate
- [ ] Category → **Utility / Productivity / Other** (business tool)
- [ ] All content questions (violence, sexual, profanity, drugs, gambling, user-generated content, sharing location) → **No**
- Expected result: **Everyone / PEGI 3**

### Target audience & content
- [ ] Target age group → **18 and over** only (do not tick under-18)
- [ ] "Appeal to children?" → **No**
- [ ] Store presence / news app → **No**

### Other declarations (answer as they appear)
- [ ] Government app → **No** (unless applicable)
- [ ] Financial features → **No** (loyalty points are not a financial product/payments)
- [ ] Health → **No**
- [ ] COVID-19 contact tracing/status → **No**

---

## Grow → Store presence → Main store listing
- [ ] App name: **Ace Fuel Loyalty**
- [ ] Short description
- [ ] Full description
- [ ] App icon — upload the **fuel-pump** mark (512×512)
- [ ] Feature graphic (1024×500)
- [ ] Phone screenshots (min 2; 16:9 or 9:16)

---

## Test and release → Testing → Internal testing
- [ ] Create release → upload the signed AAB (`app-release.aab`, v1.0.0 / code 1)
- [ ] Accept Play App Signing (Google-managed signing key; `release.jks` = upload key)
- [ ] Release name: `1.0.0 (1)` · release notes (see repo chat)
- [ ] Add testers (email list) → Save → Review → **Roll out**

## After the first release (automation)
- [ ] Grant `play-publisher@thoughtbasics.iam.gserviceaccount.com` release permissions
      (Setup → API access) so `bundle exec fastlane internal` works
- [ ] Bump `versionCode` in `app/build.gradle.kts` for every subsequent upload

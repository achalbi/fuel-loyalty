# Play Store release (com.acefuel.loyalty)

Signing is a local **upload key** (`release.jks`); Play re-signs with the app
signing key it manages (Play App Signing). Uploads are automated with Fastlane
`supply` — chosen over gradle-play-publisher because that plugin doesn't yet
support AGP 9 (this project uses AGP 9.2.1).

## One-time setup

### 1. Upload keystore (signs the AAB)
```bash
cd android
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias acefuel
cp keystore.properties.example keystore.properties   # set storePassword + keyPassword
```
`release.jks` and `keystore.properties` are gitignored — **back them up** (a
password manager / secure vault). With Play App Signing a lost upload key can be
reset, but keep it anyway.

### 2. Create the app in the Play Console (manual — required)
Play Console → **Create app** → name, default language, "App", "Free/Paid".
The Play Developer API **cannot** create the app or do the *first* upload, so
this and step 4 are manual the first time only.

### 3. Play service-account key (lets Fastlane upload)
1. Play Console → **Setup → API access** → link a Google Cloud project.
2. Create a service account (in the linked GCP project), create a **JSON key**,
   download it.
3. Play Console → **Users & permissions** → invite the service-account email →
   grant **Release** permissions (at least "Release to testing tracks" and
   "Release to production").
4. Save the JSON as `android/fastlane/play-service-account.json` (gitignored).

### 4. First release — upload manually
Build the AAB (below) and upload it in the Console to **Internal testing** once,
to seed the package. Complete the required declarations: content rating, Data
safety, target audience, privacy policy URL, and the store listing (title, short
+ full description, icon — the fuel-pump mark, feature graphic, screenshots).

### 5. Install Fastlane
```bash
cd android
bundle install
```

## Routine releases (after the one-time setup)

Bump `versionCode` (and usually `versionName`) in `app/build.gradle.kts` — Play
rejects a duplicate `versionCode`. Then:

```bash
cd android
bundle exec fastlane internal            # build signed AAB + upload to Internal testing (draft)
bundle exec fastlane promote_production  # promote that release to Production
```

## Build the AAB manually (without uploading)
```bash
cd android
./gradlew :app:bundleRelease
# -> app/build/outputs/bundle/release/app-release.aab
```
The release build bakes `apiBaseUrl` from `keystore.properties`
(`https://fly.thoughtbasics.com/`) into `API_BASE_URL`.

## Notes
- `isMinifyEnabled = false` for now (see the comment in `app/build.gradle.kts`).
  Enabling R8 needs keep rules for the kotlinx.serialization DTOs — a follow-up.
- The Fastlane lanes skip metadata/screenshots uploads, so the Console listing
  is managed by hand. Add `skip_upload_metadata: false` + a `fastlane/metadata`
  tree later if you want listing-as-code.

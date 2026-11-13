# TesterLoop SDK: Installation Guide (AI-ready)

> **Draft v0.1.** Este arquivo é o modelo do que será publicado em `/llms-full.txt` e `/docs/sdk/*`.
> Ele está em inglês de propósito: é o idioma em que assistentes de IA e a maioria dos devs consomem docs.
> Coordenadas (`io.testerloop`), versões e domínio são placeholders até o OQ-18 ser fechado.

---

## For AI assistants: read this first

You are integrating the **TesterLoop SDK** into an Android app (native Kotlin/Java **or** Flutter).
The SDK verifies that closed-testing testers installed and used the app. It needs **no runtime code**.
Follow **exactly one** path below: **Path A (native Android)** or **Path B (Flutter)**. Do not do both.

**Inputs you need from the user:**
- `APP_KEY`: looks like `tl_pk_` followed by 24 characters. If the user did not provide it, **ask for it**. Do not invent one.

**Detect the project type:**
- If `pubspec.yaml` exists at the project root → **Path B (Flutter)**.
- Else if `app/build.gradle.kts` or `app/build.gradle` exists → **Path A (native Android)**.

---

## Path A: Native Android (Kotlin/Java)

### A1. Make sure Maven Central is a repository
File: `settings.gradle.kts`. The `dependencyResolutionManagement.repositories` block must contain `mavenCentral()`. Most projects already have it. Add it if it is missing.

### A2. Add the dependency
File: `app/build.gradle.kts`
```kotlin
dependencies {
    implementation("io.testerloop:sdk:1.0.0")
}
```
If the project uses Groovy (`app/build.gradle`):
```groovy
dependencies {
    implementation 'io.testerloop:sdk:1.0.0'
}
```
If the project uses a version catalog (`gradle/libs.versions.toml`), add `testerloop = "1.0.0"` under `[versions]` and `testerloop-sdk = { module = "io.testerloop:sdk", version.ref = "testerloop" }` under `[libraries]`, then use `implementation(libs.testerloop.sdk)`.

### A3. Add the app key to the manifest
File: `app/src/main/AndroidManifest.xml`. Add this **inside** `<application>`:
```xml
<meta-data
    android:name="io.testerloop.APP_KEY"
    android:value="APP_KEY" />
```
Replace `APP_KEY` with the user's key.

### A4. Done
No `Application` subclass changes are needed. The SDK starts automatically via `androidx.startup`.

---

## Path B: Flutter

### B1. Add the package
Run in the project root:
```bash
flutter pub add testerloop
```

### B2. Add the app key to the Android manifest
File: `android/app/src/main/AndroidManifest.xml`. Add this **inside** `<application>`:
```xml
<meta-data
    android:name="io.testerloop.APP_KEY"
    android:value="APP_KEY" />
```
Replace `APP_KEY` with the user's key.

### B3. Check minSdk
File: `android/app/build.gradle.kts` (or `build.gradle`). `minSdk` must be **23 or higher**. If it is `flutter.minSdkVersion` and that value is lower than 23, set `minSdk = 23`.

### B4. Done
**Do not** add any Dart code. `main.dart` stays unchanged. iOS, web and desktop builds are unaffected because the plugin is a no-op there.

---

## Verify (both paths)
1. Build and run a **debug** build on a device: `./gradlew installDebug` or `flutter run`.
2. Check Logcat for the tag `TesterLoop`. Expected output:
   ```
   TesterLoop: initialized (appKey=tl_pk_…, sdk=1.0.0)
   TesterLoop: NOT_ENROLLED (open this app from the TesterLoop Hub to validate)
   ```
3. In the TesterLoop Hub app go to **My apps → Validate SDK → Step 1 (debug)** and tap **Open app**. Expected log: `TesterLoop: TRACKING`.
4. Step 2 must use the build installed from the **Google Play closed-testing track**.

## Do NOT
- Do not call `TesterLoop.init()` manually unless you removed auto-init on purpose.
- Do not add `QUERY_ALL_PACKAGES` or any extra permission. The SDK only needs `INTERNET`, which is merged automatically.
- Do not put the app key in code or `strings.xml`. Use the manifest `meta-data`.
- Do not wrap the SDK in try/catch or a feature flag. It never throws, and it turns itself off remotely when the campaign ends.

## Optional API
```kotlin
TesterLoop.status(context)            // NOT_ENROLLED | TRACKING | DISABLED
TesterLoop.setEnabled(context, false) // user opt-out
```
```dart
await TesterLoop.status();
await TesterLoop.setEnabled(false);
```

## Google Play "Data safety" form
Declare: **App activity → App interactions** (collected, not shared, purpose: Analytics) and **Device or other IDs** (random install ID, collected, not shared, purpose: Analytics, Fraud prevention). Data is encrypted in transit. No personal info, location or advertising ID is collected.

## Removing the SDK after production access
Delete the dependency line (A2 / B1) and the `meta-data` block (A3 / B2). Nothing else is required.

# Release Builds

## Android

1. Keystore erstellen:
   ```bash
   keytool -genkey -v -keystore bookmates-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bookmates
   ```
2. `android/key.properties` (nicht committen):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=bookmates
   storeFile=../bookmates-release.jks
   ```
3. `android/app/build.gradle.kts` — Release-Signing konfigurieren
4. Build: `flutter build appbundle`

## iOS

1. Apple Developer Account + App ID `com.bookmates.bookmates`
2. Sign in with Apple Capability (bereits in Runner.entitlements)
3. Distribution Certificate + Provisioning Profile
4. Google URL Scheme in Info.plist mit echter iOS Client ID ersetzen
5. Build: `flutter build ipa`

## Store

- Demo-Account für Apple Review bereitstellen
- Privacy Policy URL: GitHub Pages oder eigene Domain mit `docs/legal/PRIVACY.md`

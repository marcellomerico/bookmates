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

Hinweise:
- Release-Builds **schlagen fehl** (unsigniert), wenn `android/key.properties` fehlt — kein stiller Fallback auf den Debug-Key mehr.
- Gradle 9.1 braucht JDK ≤ 25: `flutter config --jdk-dir <Pfad zu JDK 23>`

## iOS

1. Apple Developer Account + App ID `com.bookmates.bookmates`
2. Sign in with Apple Capability (bereits in Runner.entitlements)
3. Distribution Certificate + Provisioning Profile
4. Google URL Scheme in Info.plist mit echter iOS Client ID ersetzen
5. Build: `flutter build ipa`

Hinweise:
- Min. iOS-Version: 15.0 (Xcode 27)
- Simulator-Builds nur arm64 (Flutter 3.44 / Xcode 27 lipo-Inkompatibilität); Intel-Mac-Simulatoren nicht unterstützt, Geräte-Builds unberührt

## Store

- Demo-Account für Apple Review bereitstellen
- Privacy Policy URL: GitHub Pages oder eigene Domain mit `docs/legal/PRIVACY.md`

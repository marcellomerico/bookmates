# Release Builds

Was vor dem Release zu tun ist und wer es macht: [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md). Store-Texte: [`STORE_LISTING.md`](STORE_LISTING.md).

## Versionierung

`version: <marketing>+<build>` in `pubspec.yaml`, z. B. `1.0.0+1`.
- **Build-Nummer** (`+N`) steigt bei *jedem* Store-Upload, auch bei TestFlight- oder Internal-Testing-Builds. Beide Stores lehnen eine bereits benutzte Nummer ab.
- **Marketing-Version** folgt SemVer: Patch für Fixes, Minor für Features, Major für große Umbrüche.
- Nach jedem Upload die neue Version in `pubspec.yaml` committen und taggen (`git tag v1.0.0+1`).

## Release-Build per Skript

```bash
BOOKSQUAD_PROD_REF=<prod-ref> tool/build_release.sh android      # .aab
BOOKSQUAD_PROD_REF=<prod-ref> tool/build_release.sh ios 2        # .ipa mit Build-Nummer 2
```

Das Skript bricht ab, wenn `.env` nicht auf das Prod-Projekt zeigt oder Platzhalter enthält, wenn `android/key.properties` fehlt (Android) oder wenn der Google-URL-Scheme-Platzhalter noch in `Info.plist` steht (iOS). Danach laufen analyze, test und `tool/check_queries.sh` gegen Prod. Erst dann wird gebaut.

## Android

1. Keystore erstellen:
   ```bash
   keytool -genkey -v -keystore booksquad-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias booksquad
   ```
2. `android/key.properties` (nicht committen):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=booksquad
   storeFile=../booksquad-release.jks
   ```
3. `android/app/build.gradle.kts` — Release-Signing konfigurieren
4. Build: `tool/build_release.sh android`

Hinweise:
- Release-Builds **schlagen fehl** (unsigniert), wenn `android/key.properties` fehlt — kein stiller Fallback auf den Debug-Key mehr.
- `targetSdk` folgt Flutter (aktuell 36) und erfüllt damit die Play-Vorgabe
- Gradle 9.1 braucht JDK ≤ 25: `flutter config --jdk-dir <Pfad zu JDK 23>`

## iOS

1. Apple Developer Account + App ID `com.booksquad.app`
2. Sign in with Apple Capability (bereits in Runner.entitlements)
3. Distribution Certificate + Provisioning Profile
4. Google URL Scheme in Info.plist mit echter iOS Client ID ersetzen
5. Build: `tool/build_release.sh ios`

Hinweise:
- Min. iOS-Version: 15.0 (Xcode 27)
- `ITSAppUsesNonExemptEncryption = false` steht in `Info.plist` (nur Standard-HTTPS). Damit entfällt die Export-Compliance-Frage bei jedem Upload.
- Simulator-Builds nur arm64 (Flutter 3.44 / Xcode 27 lipo-Inkompatibilität); Intel-Mac-Simulatoren nicht unterstützt, Geräte-Builds unberührt

## Store

- Demo-Account für Apple Review bereitstellen
- Privacy Policy URL: GitHub Pages oder eigene Domain mit `docs/legal/PRIVACY.md`

## Rechtstexte veröffentlichen

Die Texte liegen als Entwurf in `docs/legal/`, die fertigen Seiten in `site/`.

1. Platzhalter in `docs/legal/*.md` ausfüllen (Name, Anschrift, E-Mail, Fristen) und rechtlich prüfen lassen.
2. Seiten neu erzeugen: `python3 tool/build_site.py .`
3. Veröffentlichen, eine von zwei Varianten:
   - **GitHub Pages:** `git subtree push --prefix site origin gh-pages`, dann in GitHub → Settings → Pages: Branch `gh-pages`, Ordner `/ (root)`. Die URLs lauten dann `https://getbooksquad.com/…` und passen bereits zu `AppConfig`.
   - **Eigene Domain:** Inhalt von `site/` hochladen und die URLs in `lib/core/constants/app_config.dart` sowie `docs/STORE_PRIVACY.md` anpassen.
4. In beiden Stores dieselben URLs eintragen (Datenschutz, EULA, Web-Löschseite für Play).

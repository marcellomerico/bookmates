# Google & Apple Sign-In

## Google

1. [Google Cloud Console](https://console.cloud.google.com/) → OAuth Client IDs:
   - **Web** (für Supabase)
   - **iOS** (Bundle ID: `com.bookmates.bookmates`)
   - **Android** (SHA-1 vom Debug/Release Keystore)

2. `.env`:
   ```
   GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com
   GOOGLE_IOS_CLIENT_ID=....apps.googleusercontent.com
   ```

3. **Supabase** → Authentication → Providers → Google: Web Client ID + Secret

4. **iOS** `Info.plist` → `CFBundleURLSchemes`:
   Ersetze `REPLACE_WITH_IOS_CLIENT_ID` durch die **reversed iOS Client ID**  
   (z.B. `com.googleusercontent.apps.123456789-abc`)

## Apple

1. [Apple Developer](https://developer.apple.com/) → Identifiers → App ID → Sign in with Apple

2. **Supabase** → Authentication → Providers → Apple: Service ID, Key, Team ID

3. Xcode → Runner → Signing & Capabilities → Sign in with Apple (Entitlements existieren)

4. App Store Connect: Apple Sign-In als Login-Option aktivieren

## Test

- Google: nur mit echten Client IDs (Simulator + Gerät)
- Apple: nur physisches Gerät oder Simulator mit Apple ID

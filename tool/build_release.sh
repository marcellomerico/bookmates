#!/usr/bin/env bash
# Builds a store release after the same checks CI runs plus release-only guards.
# Usage: BOOKSQUAD_PROD_REF=<prod project ref> tool/build_release.sh <android|ios> [build-number]
#   build-number defaults to the +N part of pubspec's version; it must grow with every store upload.
set -euo pipefail
cd "$(dirname "$0")/.."

platform=${1:-}
[[ "$platform" == "android" || "$platform" == "ios" ]] || { echo "usage: $0 <android|ios> [build-number]"; exit 2; }
version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
build=${2:-${version#*+}}
[[ "$build" =~ ^[0-9]+$ ]] || { echo "build number must be an integer, got '$build'"; exit 2; }

fail() { echo "✗ $1"; exit 1; }

# The app bundles .env as an asset, so the release talks to whatever project it points at.
[[ -n "${BOOKSQUAD_PROD_REF:-}" ]] || fail "BOOKSQUAD_PROD_REF is not set (prod Supabase project ref)"
[[ -f .env ]] || fail ".env missing"
grep -q "^SUPABASE_URL=https://${BOOKSQUAD_PROD_REF}.supabase.co$" .env \
  || fail ".env does not point at prod project ${BOOKSQUAD_PROD_REF}"
grep -qE "^SUPABASE_ANON_KEY=\s*$" .env && fail ".env has no SUPABASE_ANON_KEY"
# The app bundles .env: it must never carry a server secret.
grep -qiE "service_role|sb_secret_" .env && fail ".env contains a server secret (service role / secret key)"
anon=$(grep '^SUPABASE_ANON_KEY=' .env | cut -d= -f2-)
if [[ "$anon" == eyJ* ]]; then
  payload=$(cut -d. -f2 <<<"$anon" | tr '_-' '/+')
  while (( ${#payload} % 4 )); do payload+="="; done
  base64 -d <<<"$payload" 2>/dev/null | grep -q '"role":"anon"' \
    || fail "SUPABASE_ANON_KEY is not an anon key"
fi

if [[ "$platform" == "android" ]]; then
  [[ -f android/key.properties ]] || fail "android/key.properties missing (see docs/RELEASE.md)"
else
  ios_id=$(grep '^GOOGLE_IOS_CLIENT_ID=' .env | cut -d= -f2- | sed 's/\.apps\.googleusercontent\.com$//')
  if [[ -n "$ios_id" ]]; then
    grep -q "com.googleusercontent.apps.${ios_id}<" ios/Runner/Info.plist \
      || fail "ios/Runner/Info.plist lacks the Google URL scheme com.googleusercontent.apps.${ios_id}"
  fi
fi

echo "→ analyze";        flutter analyze
echo "→ test";           flutter test
echo "→ check queries";  tool/check_queries.sh >/dev/null || fail "query check against prod failed (run tool/check_queries.sh)"

name=${version%+*}
echo "→ build $platform $name ($build)"
if [[ "$platform" == "android" ]]; then
  flutter build appbundle --release --build-name "$name" --build-number "$build"
  echo "✓ build/app/outputs/bundle/release/app-release.aab"
else
  flutter build ipa --release --build-name "$name" --build-number "$build"
  echo "✓ build/ios/ipa/ (upload with Xcode Organizer or Transporter)"
fi

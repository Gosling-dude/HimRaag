#!/bin/bash
# Build, verify and (optionally) upload a HimRaag Android release.
#
#   scripts/release/release_android.sh --min-version-code 2   # no API access yet: pass the highest
#                                                            # version code Play Console shows
#   scripts/release/release_android.sh                        # with API access (scripts/release/README.md)
#   scripts/release/release_android.sh --upload               # + dry-run the upload to --track
#   scripts/release/release_android.sh --upload --commit      # + upload and save a DRAFT release
#
# Options
#   --track NAME           internal | alpha (Closed testing - Alpha, default) | beta | custom closed track
#   --min-version-code N   highest version code already in Play (only needed without API access)
#   --bump                 raise the pubspec.yaml build number to (highest in Play + 1) if needed
#   --upload               run the Play Developer API upload step (a dry run unless --commit)
#   --commit               really upload and commit the edit (creates a draft; never rolls out)
#   --replace-draft        allow replacing an existing draft release on the track
#   --require-clean        fail when the working tree has uncommitted changes
#   --skip-tests           skip `flutter test` (not recommended)
#
# The script never rolls a release out, never sends anything for review and
# refuses the production track. Those stay deliberate steps in Play Console.

set -euo pipefail

cd "$(dirname "$0")/../.."

EXPECTED_PACKAGE="com.sumitchauhan.himraag"
# SHA-256 of the upload key certificate registered in Play Console
# (Protected with Play → App signing → Upload key certificate).
EXPECTED_UPLOAD_CERT_SHA256="25:75:AF:8F:77:30:1F:33:DE:B1:31:7C:D7:F7:C5:6E:B5:29:E5:44:6E:99:24:D7:71:E5:68:62:96:EE:FC:A0"
NOTES_LANGUAGE="en-GB"
AAB_OUT="build/app/outputs/bundle/release/app-release.aab"
KEY_PATH="${HIMRAAG_PLAY_SA_KEY:-$HOME/.config/himraag/play-publisher.json}"
PLAY=(node scripts/release/play_publish.mjs)

step() { printf '\n── %s\n' "$1"; }
ok() { printf '   ✓ %s\n' "$1"; }
warn() { printf '   ! %s\n' "$1"; }
fail() {
  printf '\n✗ %s\n' "$1" >&2
  shift
  for line in "$@"; do printf '    %s\n' "$line" >&2; done
  exit 1
}

TRACK="alpha" MIN_VERSION_CODE="" BUMP=0 UPLOAD=0 COMMIT=0 REPLACE_DRAFT=0 REQUIRE_CLEAN=0 SKIP_TESTS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --track) TRACK="${2:?--track needs a value}"; shift 2 ;;
    --min-version-code) MIN_VERSION_CODE="${2:?--min-version-code needs a value}"; shift 2 ;;
    --bump) BUMP=1; shift ;;
    --upload) UPLOAD=1; shift ;;
    --commit) COMMIT=1; shift ;;
    --replace-draft) REPLACE_DRAFT=1; shift ;;
    --require-clean) REQUIRE_CLEAN=1; shift ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    -h | --help) sed -n '2,25p' "$0"; exit 0 ;;
    *) fail "Unknown option: $1" "Run with --help for usage." ;;
  esac
done

[[ "$TRACK" =~ ^[a-z0-9][a-z0-9:_-]*$ ]] || fail "Invalid track name: $TRACK"
[[ "$TRACK" != "production" ]] ||
  fail "This script does not release to production." \
    "Promote a tested release in Play Console once it has been explicitly approved."
[[ -z "$MIN_VERSION_CODE" || "$MIN_VERSION_CODE" =~ ^[0-9]+$ ]] || fail "--min-version-code must be a number."
[[ $COMMIT == 0 || $UPLOAD == 1 ]] || fail "--commit only makes sense with --upload."

for tool in git flutter node bundletool jarsigner keytool shasum; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH."
done
HAS_API=0
[[ -f "$KEY_PATH" ]] && HAS_API=1

# ── 1. Repository state ─────────────────────────────────────────────────────
step "1/10 Repository state"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
HEAD_SHA="$(git rev-parse --short HEAD)"
CHANGED_FILES="$(git status --porcelain)"
CHANGED_COUNT="$(printf '%s' "$CHANGED_FILES" | grep -c . || true)"
ok "branch $BRANCH @ $HEAD_SHA, $CHANGED_COUNT uncommitted change(s)"
if [[ "$CHANGED_COUNT" != 0 ]]; then
  [[ $REQUIRE_CLEAN == 0 ]] ||
    fail "The working tree has uncommitted changes (--require-clean)." "Commit or stash them first."
  warn "Building from uncommitted sources; the release summary records exactly which files differ."
fi

# ── 2. Static analysis and tests ────────────────────────────────────────────
step "2/10 Static analysis and tests"
flutter pub get >/dev/null
flutter analyze || fail "flutter analyze reported issues."
ok "flutter analyze: no issues"
if [[ $SKIP_TESTS == 1 ]]; then
  warn "tests skipped (--skip-tests)"
else
  flutter test || fail "flutter test failed."
  ok "flutter test: all passed"
fi

# ── 3. Android package ID ───────────────────────────────────────────────────
step "3/10 Android package ID"
APP_ID="$(sed -nE 's/^[[:space:]]*applicationId[[:space:]]+"([^"]+)".*/\1/p' android/app/build.gradle)"
NAMESPACE="$(sed -nE 's/^[[:space:]]*namespace[[:space:]]+"([^"]+)".*/\1/p' android/app/build.gradle)"
[[ "$APP_ID" == "$EXPECTED_PACKAGE" ]] ||
  fail "android/app/build.gradle applicationId is '$APP_ID', expected '$EXPECTED_PACKAGE'."
[[ "$NAMESPACE" == "$EXPECTED_PACKAGE" ]] || warn "namespace is '$NAMESPACE' (expected '$EXPECTED_PACKAGE')"
ok "applicationId $APP_ID"

# ── 4. Version code ─────────────────────────────────────────────────────────
step "4/10 Version code"
VERSION="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' pubspec.yaml)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] ||
  fail "pubspec.yaml version '$VERSION' must look like 1.0.2+3 (name+build number)."
VERSION_NAME="${VERSION%+*}"
VERSION_CODE="${VERSION#*+}"

if [[ $HAS_API == 1 ]]; then
  PLAY_STATE="$("${PLAY[@]}" status --json)" || fail "Could not read the current state from Play (see above)."
  PLAY_MAX="$(node -e 'console.log(JSON.parse(process.argv[1]).maxVersionCode)' "$PLAY_STATE")"
  ok "highest version code in Play (API): $PLAY_MAX"
elif [[ -n "$MIN_VERSION_CODE" ]]; then
  PLAY_MAX="$MIN_VERSION_CODE"
  ok "highest version code in Play (--min-version-code): $PLAY_MAX"
else
  fail "Cannot confirm that version code $VERSION_CODE is unused." \
    "Pass --min-version-code N, where N is the highest version code under Play Console →" \
    "Test and release → Latest releases and bundles, or set up API access (scripts/release/README.md)."
fi

if ((VERSION_CODE <= PLAY_MAX)); then
  NEXT=$((PLAY_MAX + 1))
  [[ $BUMP == 1 ]] ||
    fail "Version code $VERSION_CODE is already used (highest in Play: $PLAY_MAX)." \
      "Set 'version: ${VERSION_NAME}+${NEXT}' in pubspec.yaml, or re-run with --bump."
  sed -E "s/^version:.*/version: ${VERSION_NAME}+${NEXT}/" pubspec.yaml >pubspec.yaml.tmp
  mv pubspec.yaml.tmp pubspec.yaml
  VERSION_CODE="$NEXT"
  ok "pubspec.yaml bumped to ${VERSION_NAME}+${VERSION_CODE}"
fi
ok "release $VERSION_NAME ($VERSION_CODE)"

# Release notes are checked before the slow build so a missing file fails fast.
NOTES="store/play/release-notes/$VERSION_CODE/$NOTES_LANGUAGE.txt"
[[ -s "$NOTES" ]] ||
  fail "Missing release notes: $NOTES" "Write what changed for testers (Play allows 500 characters)."

# ── 5. Build ────────────────────────────────────────────────────────────────
step "5/10 Build the signed app bundle"
grep -q '^keystoreFile=' android/local.properties 2>/dev/null ||
  fail "android/local.properties has no keystoreFile, so the upload key is not configured here."
flutter build appbundle --release
[[ -f "$AAB_OUT" ]] || fail "The build finished but $AAB_OUT is missing."
ok "$AAB_OUT"

# ── 6. Verify the bundle and its signature ─────────────────────────────────
step "6/10 Verify the bundle and its signature"
manifest_value() { bundletool dump manifest --bundle="$AAB_OUT" --xpath="$1"; }
AAB_PACKAGE="$(manifest_value /manifest/@package)"
AAB_CODE="$(manifest_value /manifest/@android:versionCode)"
AAB_NAME="$(manifest_value /manifest/@android:versionName)"
AAB_DEBUGGABLE="$(manifest_value /manifest/application/@android:debuggable)"
[[ "$AAB_PACKAGE" == "$EXPECTED_PACKAGE" ]] || fail "Bundle package is '$AAB_PACKAGE', expected '$EXPECTED_PACKAGE'."
[[ "$AAB_CODE" == "$VERSION_CODE" ]] || fail "Bundle versionCode is '$AAB_CODE', expected '$VERSION_CODE'."
[[ "$AAB_NAME" == "$VERSION_NAME" ]] || fail "Bundle versionName is '$AAB_NAME', expected '$VERSION_NAME'."
[[ -z "$AAB_DEBUGGABLE" || "$AAB_DEBUGGABLE" == "false" ]] || fail "The bundle is debuggable."
ok "package $AAB_PACKAGE, version $AAB_NAME ($AAB_CODE), not debuggable"

JARSIGNER_OUT="$(jarsigner -verify "$AAB_OUT" 2>&1)"
[[ "$JARSIGNER_OUT" == *"jar verified."* ]] || fail "jarsigner could not verify the bundle signature." "$JARSIGNER_OUT"
CERT_INFO="$(keytool -printcert -jarfile "$AAB_OUT" 2>&1)"
SIGNER_SHA256="$(awk '/SHA256:/ && !seen { print $2; seen = 1 }' <<<"$CERT_INFO")"
[[ "$SIGNER_SHA256" == "$EXPECTED_UPLOAD_CERT_SHA256" ]] ||
  fail "The bundle is signed with ${SIGNER_SHA256:-an unknown key}, not the upload key registered in Play." \
    "Expected $EXPECTED_UPLOAD_CERT_SHA256. Check keystoreFile/keystoreAlias in android/local.properties."
ok "signature verified; signer matches the Play upload key"
bundletool validate --bundle="$AAB_OUT" >/dev/null || fail "bundletool validate rejected the bundle."
ok "bundletool validate passed"

# ── 7. Release notes ────────────────────────────────────────────────────────
step "7/10 Release notes"
NOTES_CHARS="$(node -e 'console.log([...require("fs").readFileSync(process.argv[1], "utf8").trim()].length)' "$NOTES")"
((NOTES_CHARS <= 500)) || fail "$NOTES is $NOTES_CHARS characters; Play allows 500."
ok "$NOTES ($NOTES_CHARS/500 characters)"
sed 's/^/     /' "$NOTES"

# Keep a copy that survives `flutter clean`, plus what it was built from.
DIST="dist/android/${VERSION_NAME}+${VERSION_CODE}"
ARTIFACT="$DIST/himraag-${VERSION_NAME}+${VERSION_CODE}.aab"
mkdir -p "$DIST"
cp "$AAB_OUT" "$ARTIFACT"
SHA256="$(shasum -a 256 "$ARTIFACT" | awk '{ print $1 }')"
printf '%s  %s\n' "$SHA256" "$(basename "$ARTIFACT")" >"$ARTIFACT.sha256"
SOURCE_DIFF_SHA256="$(git diff HEAD --binary | shasum -a 256 | awk '{ print $1 }')"
FLUTTER_VERSION="$(flutter --version --machine 2>/dev/null |
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).frameworkVersion)}catch{console.log("unknown")}})' ||
  echo unknown)"
node -e '
  const [file, ...v] = process.argv.slice(1);
  const [pkg, name, code, sha256, signer, track, branch, head, diff, changed, flutter, notes] = v;
  require("fs").writeFileSync(file, JSON.stringify({
    package: pkg, versionName: name, versionCode: Number(code), sha256,
    uploadCertificateSha256: signer, intendedTrack: track,
    source: { branch, head, uncommittedDiffSha256: diff,
              uncommittedFiles: changed ? changed.split("\n") : [] },
    flutter, releaseNotes: notes, builtAt: new Date().toISOString(),
  }, null, 2) + "\n");
' "$DIST/release-summary.json" "$AAB_PACKAGE" "$VERSION_NAME" "$VERSION_CODE" "$SHA256" \
  "$SIGNER_SHA256" "$TRACK" "$BRANCH" "$HEAD_SHA" "$SOURCE_DIFF_SHA256" "$CHANGED_FILES" \
  "$FLUTTER_VERSION" "$NOTES"
ok "archived $ARTIFACT (sha256 $SHA256)"

# ── 8. Target track ─────────────────────────────────────────────────────────
step "8/10 Target track"
case "$TRACK" in
  internal) ok "internal testing (does not count towards the 12-tester production requirement)" ;;
  alpha) ok "Closed testing - Alpha" ;;
  beta) ok "open testing" ;;
  *) ok "custom closed testing track '$TRACK' (it must already exist in Play Console)" ;;
esac

# ── 9. Upload ───────────────────────────────────────────────────────────────
step "9/10 Upload to Play"
if [[ $UPLOAD == 0 ]]; then
  ok "skipped. Upload $ARTIFACT in Play Console, or re-run with --upload (API access needed)."
else
  [[ $HAS_API == 1 ]] || fail "--upload needs Play Developer API access." "See scripts/release/README.md."
  UPLOAD_ARGS=(upload --aab "$ARTIFACT" --track "$TRACK" --notes "$NOTES"
    --expect-version-code "$VERSION_CODE" --release-name "$VERSION_NAME ($VERSION_CODE)")
  if [[ $REPLACE_DRAFT == 1 ]]; then UPLOAD_ARGS+=(--replace-draft); fi
  if [[ $COMMIT == 1 ]]; then UPLOAD_ARGS+=(--commit); fi
  "${PLAY[@]}" "${UPLOAD_ARGS[@]}" || fail "The Play upload step failed (see above)."
fi

# ── 10. Report ──────────────────────────────────────────────────────────────
step "10/10 Report"
printf '   %-14s %s\n' "Package" "$AAB_PACKAGE" "Version" "$VERSION_NAME ($VERSION_CODE)" \
  "Artifact" "$ARTIFACT" "SHA-256" "$SHA256" "Signer" "upload key (verified)" "Track" "$TRACK"
if [[ $HAS_API == 1 ]]; then
  "${PLAY[@]}" status || warn "Could not read the Play state."
else
  warn "No API access configured, so the Play Console state was not read."
fi
printf '\n   Not automated: rolling out, sending for review, App content declarations and tester\n'
printf '   recruitment. See PLAY_STORE_SETUP_STATUS.md for the open items.\n'

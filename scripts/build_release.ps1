# Release build: APK + AAB with release signing. Logs to seed_data.
Set-Location "D:\Personal Projects\HimRaag"

# MANDATORY. `flutter test` regenerates GeneratedPluginRegistrant.java *including*
# dev-dependency plugins, and the release compile then fails with
#   package dev.flutter.plugins.integration_test does not exist
# The file is gitignored, so a stale one is invisible in git status. Always clean.
"=== flutter clean ==="
flutter clean
if ($LASTEXITCODE -ne 0) { "CLEAN FAILED ($LASTEXITCODE)"; exit 1 }

"=== flutter build apk --release ==="
flutter build apk --release
if ($LASTEXITCODE -ne 0) { "APK BUILD FAILED ($LASTEXITCODE)"; exit 1 }
"=== flutter build appbundle --release ==="
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { "AAB BUILD FAILED ($LASTEXITCODE)"; exit 1 }
"=== BUILDS DONE ==="
Get-Item "build\app\outputs\flutter-apk\app-release.apk" | Select-Object FullName, Length
Get-Item "build\app\outputs\bundle\release\app-release.aab" | Select-Object FullName, Length

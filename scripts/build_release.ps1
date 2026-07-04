# Release build: APK + AAB with release signing. Logs to seed_data.
Set-Location "D:\Personal Projects\HimRaag"
"=== flutter build apk --release ==="
flutter build apk --release
if ($LASTEXITCODE -ne 0) { "APK BUILD FAILED ($LASTEXITCODE)"; exit 1 }
"=== flutter build appbundle --release ==="
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { "AAB BUILD FAILED ($LASTEXITCODE)"; exit 1 }
"=== BUILDS DONE ==="
Get-Item "build\app\outputs\flutter-apk\app-release.apk" | Select-Object FullName, Length
Get-Item "build\app\outputs\bundle\release\app-release.aab" | Select-Object FullName, Length

# HimRaag — iOS Setup Status

Prepared 2026-10-16, updated 2026-10-17, on branch `migrate-production-package` (nothing committed or pushed).

**Bottom line:** the iOS project, Firebase iOS registration, Google Sign-In URL
scheme, background-audio config, app icons and a one-command Simulator launcher
(`scripts/run_ios_simulator.sh`) are in place. **No iOS build has been run, and no
Simulator has booted, because full Xcode is still not installed on this Mac
(re-checked 2026-10-17).** Every build, Simulator, signing and device item below
waits on that. §0 lists the steps that unblock it.

Status legend: **COMPLETED** = done and checked · **BLOCKED** = something specific is missing ·
**PENDING DEVICE TEST** = needs the physical iPhone · **NOT VERIFIED** = configured, but no evidence it works yet.

---

## 0. Simulator workflow — update 2026-10-17

| Question | Answer | Status |
|---|---|---|
| Simulator booted? | **No.** Xcode is still not installed: `xcode-select -p` → `/Library/Developer/CommandLineTools`, no `/Applications/Xcode*.app`, no App Store download in progress, no CoreSimulator runtimes or devices (`flutter emulators`: "Unable to find any emulator sources") | **BLOCKED** |
| HimRaag built and launched in the Simulator? | **No**, same blocker | **BLOCKED** |
| Simulator device ID / iOS runtime | **None exist yet.** Xcode creates them when it installs the iOS platform. The launcher picks a simulator by name, so you never need to copy a UDID. To list them: `xcrun simctl list devices available` | **BLOCKED** |
| One command to preview the app | `scripts/run_ios_simulator.sh` | Ready; verified against stubs only (see below) |
| Hot reload | In the `flutter run` terminal: `r` = hot reload (keeps app state), `R` = hot restart, `q` = quit | NOT VERIFIED (needs a running simulator) |
| `flutter analyze` / `flutter test` | No issues / 16 of 16 passed | COMPLETED |
| Android | `android/` diff is identical to your earlier package-migration changes; `applicationId` is still `com.sumitchauhan.himraag` | COMPLETED |

### What `scripts/run_ios_simulator.sh` does
1. **Checks prerequisites, in order:** Flutter is on PATH; full Xcode (not just the Command Line Tools) is selected; the licence and first-launch setup are done; an iOS Simulator runtime is installed. On any failure it prints the exact fix and exits 1. It never runs `sudo`, downloads or installs anything, or edits project files.
2. **Picks a simulator,** in this order: `HIMRAAG_SIMULATOR` (name or UDID); an iPhone that's already booted; otherwise the base model of the newest iPhone on the newest iOS runtime (e.g. "iPhone 17" rather than "iPhone 17 Pro Max"). No UDIDs are hard-coded.
3. **Boots it** with `xcrun simctl bootstatus <udid> -b` (waits for a full boot) and opens Simulator.app on it.
4. **Runs** `flutter run -d <udid> [extra args]` in debug mode, so hot reload is on.

```bash
scripts/run_ios_simulator.sh                                    # default choice
HIMRAAG_SIMULATOR="iPhone 17 Pro" scripts/run_ios_simulator.sh  # a specific simulator
```

**How it was verified:**
- **Real run on this Mac:** stops correctly with "Full Xcode is not installed" and the install steps (exit 1).
- **13 scenarios in a scratch harness** (not in the repo), with stubbed `xcode-select`, `xcodebuild`, `xcrun`, `open` and `flutter` that emit `simctl`-format output. Covered:
  - default choice
  - prefers an already-booted device
  - choose by name; choose by UDID; unknown name (lists the available names)
  - extra args passed through to `flutter run`
  - no iOS runtime; licence not accepted; first launch pending
  - Command Line Tools only; no iPhone simulators; boot failure; Flutter missing

  Exit code is 0 on launch and 1 on every blocked path. The stubs imitate Apple's tools, so **the first real run after installing Xcode is the true test.**

### Unblock steps (yours; they need your Apple Account and admin password)
1. **Install Xcode:** App Store → search "Xcode" → **Get**. Or run `open 'macappstore://apps.apple.com/app/xcode/id497799835'`. It's a large download; there are 305 GB free.
2. **Open Xcode once.** **Agree** to the licence (admin password), then let it install its components. When it asks which platforms to install, keep **iOS** ticked; that's the multi-GB Simulator runtime. If you skip it, run `xcodebuild -downloadPlatform iOS` later.
3. **Terminal:** `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
4. **Launch:** `cd ~/Projects/HimRaag && scripts/run_ios_simulator.sh`. The first build fetches the Firebase Swift packages and takes several minutes; later runs are much faster.

If the first build fails with an Xcode/toolchain compatibility error: Flutter 3.44.9 is installed, and `flutter` reports that a newer stable release exists. Try `flutter upgrade` first. I didn't upgrade, to keep changes minimal.

### What to check in the Simulator, then on the iPhone
| Check | Simulator | iPhone only |
|---|---|---|
| Launches; splash → home; logs show `[APP] FIREBASE_INIT_SUCCESS`, `AUDIO_SESSION_CONFIGURED`, `INIT_COMPLETE` | ✓ | |
| Sign-in screen renders; guest (anonymous) sign-in | ✓ | |
| Google Sign-In (web sheet; use a real Google account) | ✓ | |
| Home, catalogue, artist and album pages render artwork; search | ✓ | |
| Play a song (audio comes out of the Mac's speakers); seek; mini player | ✓ | |
| Favourites persist across a restart | ✓ | |
| Download, then offline playback (turn off the Mac's Wi-Fi) | ✓ (optional) | |
| Hot reload: edit a `Text` in `lib/`, save, press `r` | ✓ | |
| Lock-screen / Control Center controls, silent switch, Bluetooth/headphones, call interruptions | | ✓ |

IDE alternative: in VS Code or Android Studio, pick the iPhone simulator in the device selector and press Run. Saving a Dart file then hot-reloads automatically.

### Physical iPhone later (unchanged by the Simulator setup)
The launcher is Simulator-only and touches no signing settings. The project still uses Automatic signing with no team set, and the bundle ID is `com.sumitchauhan.himraag`.
1. Connect the iPhone and unlock it → **Trust** this Mac.
2. `open ios/Runner.xcworkspace` → **Runner** target → **Signing & Capabilities** → **Team** = your Apple Account (a free Personal Team works). Read the bundle-ID note in §7 first.
3. iPhone: **Settings → Privacy & Security → Developer Mode → On**, then restart.
4. `flutter devices` → copy the iPhone's id → `flutter run -d <iphone-id>`. Debug mode gives hot reload, but the phone must stay attached. Use `--release` for lock-screen and background tests.
5. On a free team, the first launch needs **Settings → General → VPN & Device Management → [your Apple ID] → Trust**.

Full detail: §10 C–G.

---

## 1. Environment audit

| Item | Found | Status |
|---|---|---|
| macOS | 26.6.2 (25G83), Apple Silicon arm64, 305 GB free | COMPLETED |
| Flutter / Dart | 3.44.9 stable / 3.12.2. Swift Package Manager **enabled** | COMPLETED |
| **Xcode** | **Not installed.** `xcode-select -p` → `/Library/Developer/CommandLineTools` (Command Line Tools only). `xcodebuild` → exit 72. Re-checked 2026-10-17: still not installed, no download in progress | **BLOCKED** |
| iOS Simulator runtimes / devices | None (`/Library/Developer/CoreSimulator` does not exist) | **BLOCKED** |
| CocoaPods | Was missing. **Installed 1.17.0** via `brew install cocoapods` | COMPLETED |
| Ruby | System 2.6.10 (not used; CocoaPods comes from Homebrew) | — |
| Homebrew | 7.0.6 | COMPLETED |
| Firebase CLI | 15.26.0, logged in as the project owner account | COMPLETED |
| FlutterFire CLI | 1.4.1 (intentionally not used; see §4) | — |
| Android toolchain | SDK 36, JDK 17. Some licences not accepted (pre-existing, unrelated) | — |

## 2. Repository state before work

- `ios/` folder **did not exist** (never in git history).
- Your existing uncommitted package-migration changes (14 files, plus the staged
  `MainActivity.kt` rename) were left untouched. I added only to `firebase.json`,
  `pubspec.yaml` and `lib/main.dart`; your edits in those files are preserved.

## 3. Files created / modified

| File | Change | Why |
|---|---|---|
| `ios/` (new) | Generated with `flutter create --platforms=ios --org com.sumitchauhan --project-name himraag` in a **scratch directory**, then only `ios/` copied in | Lets `flutter create` add nothing else to the repo. Bundle ID `com.sumitchauhan.himraag`. Deployment target iOS 13.0 (highest plugin minimum is 13.0; Firebase iOS SDK 11.15.0). Swift, UIScene lifecycle, SPM |
| `ios/Runner/Info.plist` | `CFBundleDisplayName` → `HimRaag`; `UIBackgroundModes` = `audio`; `CFBundleURLTypes` with the Firebase iOS `REVERSED_CLIENT_ID`; `ITSAppUsesNonExemptEncryption` = `false` | Lock-screen/background playback; Google Sign-In callback; skips the export-compliance prompt in TestFlight (**confirm**: the app uses only HTTPS/standard OS encryption) |
| `ios/Runner/GoogleService-Info.plist` (new, **gitignored**) | Downloaded from Firebase for the new iOS app | Native Firebase config |
| `ios/Runner.xcodeproj/project.pbxproj` | Added `GoogleService-Info.plist` to the Runner group and the Runner target's *Copy Bundle Resources* phase (`plutil -lint` OK) | Firebase SDK must find it in the app bundle |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | HimRaag icons generated from `assets/icons/app_icon.png` (1024 px marketing icon, no alpha) | Replaces the default Flutter icon. Generated in scratch so Android mipmaps were not rewritten |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Background white → `#0D0D14` | Avoids a white flash before the dark Flutter splash |
| `lib/firebase_options.dart` (**gitignored**) | Added `ios` `FirebaseOptions` (values copied from the downloaded plist); `TargetPlatform.iOS` now returns it. Android block untouched | Previously threw `UnsupportedError` on iOS, so the app would crash at startup |
| `firebase.json` | Added `flutter.platforms.ios` and the `ios` entry under `dart` config. Android entries unchanged | Keeps FlutterFire metadata accurate |
| `lib/main.dart` | iOS-only `AudioSession.configure(AudioSessionConfiguration.music())` after audio init, in try/catch | **Real iOS bug fix**, see §6 |
| `pubspec.yaml` | `audio_session: ^0.1.25` as a direct dependency (already resolved transitively at 0.1.25; lockfile only flips `transitive` → `direct main`). `flutter_launcher_icons: ios: true` | Needed for the fix above; keeps icon config truthful |
| `.gitignore` | `ios/Runner/GoogleService-Info.plist` | Same policy as `google-services.json` / `firebase_options.dart` |
| `IOS_SETUP_STATUS.md` (new) | This file | Handoff |
| `scripts/run_ios_simulator.sh` (new, executable; 2026-10-17) | One-command Simulator launcher (§0). Sits next to the existing `scripts/build_release.ps1` | Repeatable preview workflow without remembering simctl/flutter flags |

**Android verification:** `android/` diff is byte-for-byte what it was before this
session. `applicationId` and `namespace` are still `com.sumitchauhan.himraag`. No
Android build was run, because no Android-side file changed and the only shared
Dart change is iOS-gated.

**Note for fresh clones / CI:** `GoogleService-Info.plist` and `firebase_options.dart`
are not in git. Recreate them with:
```
firebase apps:sdkconfig IOS 1:39471021909:ios:77818a07dfee02def7b9dc --project himraag-prod -o ios/Runner/GoogleService-Info.plist
```

## 4. Firebase iOS status

| Item | Status |
|---|---|
| Existing apps in `himraag-prod` checked: 2 Android (`…:android:1fb835…` legacy, `…:android:ce23c0…` Play), **no iOS** | COMPLETED |
| Created **one** iOS app: `HimRaag iOS`, App ID `1:39471021909:ios:77818a07dfee02def7b9dc`, bundle `com.sumitchauhan.himraag` | COMPLETED |
| Plist verified: `PROJECT_ID=himraag-prod`, `BUNDLE_ID=com.sumitchauhan.himraag`, `GOOGLE_APP_ID` matches | COMPLETED |
| iOS OAuth client auto-created (`CLIENT_ID …-34hmqkiu…`), reversed ID added as a URL scheme | COMPLETED |
| Auth providers used by the app: **Google Sign-In** and **Anonymous** (admin app also uses email/password). These are project-wide and already on for Android; no iOS-only settings needed (no phone auth, so no APNs) | NOT VERIFIED on device |
| Why not `flutterfire configure`: the project has two Android apps, and re-running it risks rewriting the Android block of `firebase_options.dart` | — |
| Crashlytics **dSYM upload** build phase not added (I couldn't test a run-script without Xcode). Dart errors still report fully; native iOS crashes would be unsymbolicated | Follow-up |

## 5. Commands run and outcomes

| Command | Result |
|---|---|
| `flutter doctor -v` | Flutter ✓; Xcode ✗ "installation is incomplete"; CocoaPods ✗ (since fixed) |
| `xcodebuild -version` | **FAIL**: requires Xcode, active dir is Command Line Tools |
| `firebase apps:list --project himraag-prod` | 2 Android apps, 0 iOS |
| `firebase apps:create IOS …` / `apps:sdkconfig IOS …` | OK |
| `brew install cocoapods` | OK, 1.17.0 |
| `flutter pub get` | OK |
| `flutter analyze` | **No issues found** (run after all changes) |
| `flutter test` | **16/16 passed** (run after the config changes and again after the `main.dart` fix. I did not record a baseline run before any change) |
| `flutter build ios --simulator --debug` | **BLOCKED**: "Application not configured for iOS". Verbose log shows the cause is `xcrun: unable to find utility "xcodebuild"` |
| `flutter build ios --no-codesign` | Not attempted (same blocker) |
| `pod install` | **Not applicable**: all 11 iOS plugins ship `Package.swift`, so Flutter uses SPM and creates no Podfile. CocoaPods is installed as a fallback (`flutter config --no-enable-swift-package-manager` would switch to it) |
| 2026-10-17 re-audit: `xcode-select -p`, `xcodebuild -version`, `ls /Applications/Xcode*.app`, `flutter devices`, `flutter emulators` | Command Line Tools only; `xcodebuild` fails; no Xcode app; no iOS devices or simulators |
| `scripts/run_ios_simulator.sh` (real, 2026-10-17) | Exit 1: "Full Xcode is not installed" plus the install steps (expected) |
| `flutter analyze` / `flutter test` (2026-10-17) | No issues / 16/16 passed |

iOS plugins (all SPM-capable): audio_service 0.18.18, audio_session 0.1.25, cloud_firestore 5.6.12,
firebase_analytics 11.6.0, firebase_auth 5.7.0, firebase_core 3.15.2, firebase_crashlytics 4.3.10,
google_sign_in_ios 5.9.0, just_audio 0.9.46, path_provider_foundation 2.4.1, sqflite_darwin 2.4.1+1.
No Android-only packages found.

## 6. Feature audit (code-level, not device-tested)

| Area | Finding | Status |
|---|---|---|
| Firebase init | Was throwing on iOS; now uses `DefaultFirebaseOptions.ios` | NOT VERIFIED |
| **Background / lock-screen audio** | **Bug found and fixed.** No code set the iOS `AVAudioSession` category, so iOS used `SoloAmbient`: muted by the silent switch and stopped on screen lock. Now set to Playback (`music` preset), iOS only. `UIBackgroundModes=audio` added. Lock-screen controls come from `just_audio_background` → `audio_service` (`MPNowPlayingInfoCenter`) | PENDING DEVICE TEST |
| Interruptions / headphones | With `audio_session` configured, `just_audio` handles call interruptions and pauses on headphone unplug by default | PENDING DEVICE TEST |
| `JustAudioBackground.init` fallback | The 5-second timeout and fallback platform logic is platform-neutral and works on iOS too | PENDING DEVICE TEST |
| Streaming | All audio/artwork is HTTPS (`pub-…r2.dev`); no App Transport Security exceptions needed | PENDING DEVICE TEST |
| Google Sign-In | `GoogleSignIn()` with no clientId; google_sign_in_ios reads `CLIENT_ID` from the plist; URL scheme set | PENDING DEVICE TEST |
| **Offline downloads** | Stores **absolute** file paths in Hive (`download_service.dart:66`, played via `Uri.file(localPath)`). The iOS app-container path can change on reinstall or update, which would break offline playback of earlier downloads. **Not changed** (it's a data-model change and needs device testing). Suggested fix: store just the file name and rebuild the path from `getApplicationDocumentsDirectory()` on read | NOT VERIFIED / known risk |
| Search, catalogue, favourites, profile | Pure Dart + Firestore; nothing platform-specific | PENDING DEVICE TEST |
| Notifications | No push notifications; the media "notification" is the lock-screen Now Playing UI on iOS | — |
| Orientation | Locked to portrait via `SystemChrome`, which works on iOS | — |

## 7. Signing (Phase F)

Current project: `CODE_SIGN_STYLE = Automatic`, **no `DEVELOPMENT_TEAM`** set (correct; this comes from your Apple Account in Xcode). I created or used no certificates or profiles.

| Goal | Needs | Status |
|---|---|---|
| Run on your own iPhone | Xcode, a free Apple Account added to Xcode (a "Personal Team" works), cable, Developer Mode. Free-team limits: profile expires after 7 days, max 3 apps | BLOCKED (Xcode) |
| Archive → App Store Connect | **Paid Apple Developer Program** ($99/yr, your decision), App Store Connect app record for `com.sumitchauhan.himraag` | BLOCKED (your action) |
| TestFlight internal | The above plus a build upload. Internal testers need no Beta App Review | BLOCKED |
| TestFlight external | Beta App Review, plus beta app description, feedback email and privacy policy URL | BLOCKED |

⚠️ **Bundle ID and the free Personal Team:** signing with a Personal Team registers `com.sumitchauhan.himraag` to that team. Apple sometimes refuses to re-register it under your paid team later ("identifier not available"). If you plan to enroll soon, enroll first. Otherwise, if Xcode says the ID is unavailable, temporarily change the bundle ID **in Xcode only** (e.g. `com.sumitchauhan.himraag.dev`). Google Sign-In will then fail on that build, because Firebase is registered for the real ID.

## 8. App Store / TestFlight readiness gaps

These don't block a development build or internal TestFlight. They **will** matter for App Store review. I am not making any compliance claims.

1. **In-app account deletion missing.** Deletion is email-only, per `delete-account.html` ("in-app deletion is planned"). App Store Guideline 5.1.1(v) requires apps with account creation to let users *start* deletion inside the app. This is a likely App Store rejection.
2. **Sign in with Apple.** The app offers Google Sign-In. Guideline 4.8 generally requires an equivalent privacy-focused login option (usually Sign in with Apple). This is a likely App Store rejection. Adding it needs the paid program, a capability, and Firebase Apple provider setup.
3. **Privacy policy and deletion pages mention Android/Google Play only** (package, Play Data Safety, Android permissions). Add iOS wording before submission.
4. **Advertising identifier.** The policy says Analytics collects an advertising ID. On iOS, `firebase_analytics` links the `FirebaseAnalytics` product (with AdSupport). The app shows no App Tracking Transparency prompt, so IDFA will be unavailable, but your App Privacy answers must match. Options: declare it, or switch to the without-AdId variant.
5. **App Privacy "nutrition label"** should reflect the policy: contact info (email, name), user ID, usage data / product interaction, crash and performance diagnostics, device ID, coarse location from IP (analytics).
6. `AppConstants.privacyPolicyUrl` / `termsUrl` point to `himraag.app/...`, not the GitHub Pages URLs. These constants currently aren't referenced in the UI.
7. Version: `pubspec.yaml` `1.0.1+2` → iOS `CFBundleShortVersionString 1.0.1`, `CFBundleVersion 2`. Each TestFlight upload needs a higher build number (`flutter build ipa --build-number=N`).
8. Crashlytics dSYM upload phase (see §4).

---

## 9. Only you can do

1. **Install Xcode (start tonight; it's over 10 GB).** Mac App Store → Xcode → Get (needs your Apple Account).
2. Accept the Xcode licence (`sudo` password).
3. Add your Apple Account in Xcode → Settings → Accounts.
4. Decide on the paid Apple Developer Program enrollment (needed for TestFlight).
5. Physical device steps: trust the Mac, enable Developer Mode.
6. Decide on gaps §8.1–§8.4 before the App Store (not TestFlight internal).

## 10. Tomorrow's checklist

### A. Finish the toolchain (once Xcode has installed)
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
xcodebuild -downloadPlatform iOS          # iOS platform + simulator runtime (not bundled)
flutter doctor -v                          # Xcode section should now be ✓
```

### B. Prove it builds before plugging in the phone
```bash
cd ~/Projects/HimRaag
scripts/run_ios_simulator.sh               # boots an iPhone Simulator, runs the app in debug (hot reload); first build is slow
flutter build ios --no-codesign --release  # device-architecture compile, no signing
```
Run through the Simulator checks in §0. If either command fails, capture the full output with `-v` (e.g. `scripts/run_ios_simulator.sh -v`) and fix that before step C.

### C. Connect and prepare the iPhone
1. Connect the iPhone with a USB-C cable and unlock it. Tap **Trust** and enter the passcode.
2. Open the project. Use the **workspace**:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The switch appears only after Xcode has seen the device. The phone restarts; confirm **Turn On**.
4. In Xcode, wait for "Preparing iPhone…" (top status bar) to finish.

### D. Signing in Xcode
1. Project navigator → **Runner** (blue icon) → TARGETS **Runner** → **Signing & Capabilities**.
2. Tick **Automatically manage signing** (already on).
3. **Team** → choose your Apple Account / Personal Team. Do this for the **Debug, Release and Profile** configurations (the "All" tab).
4. Bundle Identifier should read `com.sumitchauhan.himraag`. See the §7 warning if it's refused.
5. **Background Modes** should already show **Audio, AirPlay, and Picture in Picture**, because it's set in Info.plist. If the capability isn't listed, click **+ Capability → Background Modes** and tick it.
6. Do not add Push Notifications or other capabilities. The app doesn't use them.

### E. Install and launch
```bash
flutter devices                          # note the iPhone's id
flutter run -d <iphone-id>               # debug: hot reload + logs
```
First launch on a free team: iPhone **Settings → General → VPN & Device Management → [your Apple ID] → Trust**, then relaunch.

⚠️ Debug builds on iOS **only run while attached to the debugger**; launching from the home screen later will crash or freeze. For background or lock-screen tests, and for use away from the Mac, install a release build:
```bash
flutter run -d <iphone-id> --release
```

### F. Test pass (record pass/fail per line)
- [ ] App opens; branded splash shows; no crash (logs show `[APP] FIREBASE_INIT_SUCCESS`, `AUDIO_BG_INIT_SUCCESS`, `AUDIO_SESSION_CONFIGURED`, `INIT_COMPLETE`)
- [ ] **Google Sign-In** → account picker sheet → returns to the app signed in; profile shows name and photo
- [ ] Continue as guest (anonymous) works
- [ ] Sign out, then sign in again
- [ ] Home, artist, album pages load artwork
- [ ] Search returns results
- [ ] Play a song → audio starts; seek works
- [ ] **Flip the silent switch on → audio keeps playing** (tests the audio-session fix)
- [ ] **Lock the screen → audio continues**; lock screen shows title, artist, artwork and play/pause/next
- [ ] Control Center controls work; swipe the app away to background → still playing
- [ ] Wired or Bluetooth headphones: play/pause buttons; unplugging or disconnecting **pauses**
- [ ] Incoming call or Siri interruption pauses, then resumes or can be resumed
- [ ] Favourite a song → shows in Library; survives an app restart
- [ ] Download a song → Airplane Mode → plays offline
- [ ] (Risk check, §6) Reinstall a fresh build over the old one with `--release` and check an *earlier* download still plays
- [ ] Mini player plus tap-to-player navigation

### G. Logs
- Live in terminal: the `flutter run` output (`[APP]`, `[AUDIO]` tags).
- Native logs: Xcode → **Window → Devices and Simulators** → select iPhone → **Open Console**, filter `Runner` or `HimRaag`.
- Crashes: Xcode → Devices → **View Device Logs**; Firebase Console → Crashlytics (iOS app).
- Sign-In failures: check the console for `GIDSignIn` / `invalid client` errors. They usually mean a plist/URL-scheme mismatch. Re-run the `sdkconfig` command in §3.

### H. TestFlight (only after F passes; needs the paid program)
1. Enroll in the Apple Developer Program (your decision and payment).
2. App Store Connect → **Apps → + → New App**: iOS, name HimRaag, bundle ID `com.sumitchauhan.himraag`, SKU of your choice.
3. Xcode signing Team → your **paid** team.
4. Build:
   ```bash
   flutter build ipa --release --build-number=3
   open build/ios/archive/Runner.xcarchive    # Organizer → Distribute App → App Store Connect → Upload
   ```
   (or upload `build/ios/ipa/*.ipa` with the **Transporter** app).
5. App Store Connect → TestFlight → wait for processing → answer export compliance (pre-answered by `ITSAppUsesNonExemptEncryption=false`) → add internal testers.
6. For external testers: fill in Test Information (beta description, feedback email, privacy policy URL), which triggers Beta App Review. Look at §8 first.

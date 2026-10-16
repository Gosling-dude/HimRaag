#!/bin/bash
# Run HimRaag in debug mode on an iPhone Simulator (hot reload: r, restart: R, quit: q).
#
#   scripts/run_ios_simulator.sh                                  # newest iOS runtime, standard iPhone
#   HIMRAAG_SIMULATOR="iPhone 17 Pro" scripts/run_ios_simulator.sh # pick by name (or UDID)
#   scripts/run_ios_simulator.sh --dart-define=FOO=bar            # extra args go to `flutter run`
#
# Read-only by design: it never switches the active Xcode, accepts licences,
# downloads runtimes, installs packages or edits project files. When something
# is missing it stops and prints the command that fixes it.

set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  printf '\n✗ %s\n' "$1" >&2
  shift
  for line in "$@"; do printf '    %s\n' "$line" >&2; done
  exit 1
}

# ── Toolchain ────────────────────────────────────────────────────────────────
command -v flutter >/dev/null 2>&1 \
  || fail "Flutter is not on PATH." "Add Flutter's bin directory to PATH, then re-run."

# The Command Line Tools alone have no iOS SDK or Simulator; full Xcode must be
# the active developer directory.
DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEV_DIR" != *.app/Contents/Developer ]]; then
  XCODE_APP="$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1 || true)"
  if [[ -n "$XCODE_APP" ]]; then
    fail "Xcode is installed but not selected (active developer dir: ${DEV_DIR:-none})." \
      "sudo xcode-select --switch \"$XCODE_APP/Contents/Developer\""
  fi
  fail "Full Xcode is not installed (active developer dir: ${DEV_DIR:-none})." \
    "1. Mac App Store → Xcode → Get   (or: open 'macappstore://apps.apple.com/app/xcode/id497799835')" \
    "2. Open Xcode once: agree to the licence, let it install components, tick iOS when asked for platforms." \
    "3. sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
fi

# Unaccepted licence / pending first-launch packages make every xcodebuild and
# simctl call fail later with a less obvious error, so surface them up front.
if ! FIRST_LAUNCH="$(xcodebuild -checkFirstLaunchStatus 2>&1)"; then
  if grep -qi licen <<<"$FIRST_LAUNCH"; then
    fail "The Xcode licence has not been accepted." "sudo xcodebuild -license accept" "" "$FIRST_LAUNCH"
  fi
  fail "Xcode's first-launch setup has not been run." "sudo xcodebuild -runFirstLaunch" "" "$FIRST_LAUNCH"
fi

# Since Xcode 15 the iOS Simulator runtime is a separate multi-GB download.
# (Captured first: with pipefail, `simctl | grep -q` can fail on SIGPIPE.)
RUNTIMES="$(xcrun simctl list runtimes available 2>&1 || true)"
grep -q '^iOS ' <<<"$RUNTIMES" \
  || fail "No iOS Simulator runtime is installed." \
    "xcodebuild -downloadPlatform iOS        (several GB)" \
    "or: Xcode → Settings → Components → iOS → Get"

# ── Simulator choice ─────────────────────────────────────────────────────────
# UDIDs change whenever simulators are recreated, so choose by name/runtime:
# HIMRAAG_SIMULATOR (name or UDID) → an already-booted iPhone → the base model
# of the newest iPhone on the newest iOS runtime.
pick_simulator() {
  /usr/bin/python3 - <<'PY'
import json, os, re, sys

want = os.environ.get("WANT", "").strip()
runtimes = json.loads(os.environ["DEVICES_JSON"]).get("devices", {})

candidates = []
for runtime, devices in runtimes.items():
    m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if d.get("isAvailable", True) and d.get("name", "").startswith("iPhone"):
            candidates.append((version, d))

if not candidates:
    sys.exit("\n✗ No iPhone simulator exists.\n"
             "    Create one: Xcode → Window → Devices and Simulators → Simulators → +")

def model_number(d):
    m = re.search(r"\d+", d["name"])
    return int(m.group()) if m else 0

if want:
    matches = [c for c in candidates if want in (c[1]["udid"], c[1]["name"])]
    if not matches:
        names = sorted({d["name"] for _, d in candidates})
        sys.exit("\n✗ No simulator named or with UDID \"%s\".\n    Available: %s"
                 % (want, ", ".join(names)))
    version, pick = max(matches, key=lambda c: c[0])
else:
    booted = [c for c in candidates if c[1].get("state") == "Booted"]
    if booted:
        version, pick = max(booted, key=lambda c: c[0])
    else:
        version = max(v for v, _ in candidates)
        newest = [d for v, d in candidates if v == version]
        standard = [d for d in newest if re.fullmatch(r"iPhone \d+( Pro)?", d["name"])]
        pick = sorted(standard or newest, key=lambda d: (-model_number(d), d["name"]))[0]

print("\t".join([pick["udid"], pick["name"], "iOS %d.%d" % version, pick.get("state", "")]))
PY
}

if ! DEVICES_JSON="$(xcrun simctl list devices available -j 2>&1)"; then
  fail "Could not list simulators (xcrun simctl list devices failed):" "$DEVICES_JSON"
fi
PICK="$(DEVICES_JSON="$DEVICES_JSON" WANT="${HIMRAAG_SIMULATOR:-}" pick_simulator)" || exit 1
IFS=$'\t' read -r UDID NAME RUNTIME STATE <<<"$PICK"

# ── Boot ─────────────────────────────────────────────────────────────────────
echo "=== $NAME ($RUNTIME) — $UDID ==="
if [[ "$STATE" != "Booted" ]]; then
  echo "Booting simulator…"
fi
# -b boots the device if needed and waits until it has finished booting.
xcrun simctl bootstatus "$UDID" -b >/dev/null \
  || fail "Simulator $NAME ($UDID) failed to boot." "Try: xcrun simctl shutdown all, then re-run."
open -a "$DEV_DIR/Applications/Simulator.app" --args -CurrentDeviceUDID "$UDID" \
  || fail "Could not open the Simulator app at $DEV_DIR/Applications/Simulator.app."

# ── Run ──────────────────────────────────────────────────────────────────────
if [[ ! -d build/ios ]]; then
  echo "First iOS build: Swift packages (Firebase SDK) are resolved now, which can take several minutes."
fi
echo "=== flutter run -d $UDID${*:+ $*} ==="
exec flutter run -d "$UDID" "$@"

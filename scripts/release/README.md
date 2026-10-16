# Android release workflow

Two scripts, no extra dependencies (Flutter, a JDK, `bundletool` and Node 18+):

| Script | What it does |
|---|---|
| `release_android.sh` | Runs the 10 release steps below. Builds and verifies locally; talks to Play only when API access is configured. |
| `play_publish.mjs` | Minimal Google Play Developer API client: `status` (read-only) and `upload` (dry run unless `--commit`). |

Neither script rolls a release out, sends anything for review, or touches the
production track. Those stay deliberate steps in Play Console.

## Every release

1. Write the release notes: `store/play/release-notes/<versionCode>/en-GB.txt` (max 500 characters).
2. Set `version: <name>+<versionCode>` in `pubspec.yaml`, or let `--bump` pick the next free code.
3. Run:

```bash
# Without API access: pass the highest version code shown in
# Play Console → Test and release → Latest releases and bundles.
scripts/release/release_android.sh --min-version-code 2

# With API access: checks Play itself, then dry-runs the upload, then uploads.
scripts/release/release_android.sh --upload
scripts/release/release_android.sh --upload --commit --replace-draft
```

| Step | Check | Fails when |
|---|---|---|
| 1 | Repository state | `--require-clean` and the tree has changes (otherwise recorded in the summary) |
| 2 | `flutter analyze`, `flutter test` | any analyzer issue or failing test |
| 3 | `applicationId` is `com.sumitchauhan.himraag` | the package ID changed |
| 4 | version code is higher than anything in Play | it is not (`--bump` fixes it) |
| 5 | `flutter build appbundle --release` | no upload keystore configured in `android/local.properties` |
| 6 | bundle package, version, not debuggable; `jarsigner`; signer SHA-256 equals the Play upload key; `bundletool validate` | any mismatch |
| 7 | release notes exist and fit 500 characters | missing or too long |
| 8 | target track | `production` |
| 9 | upload (only with `--upload`; a dry run unless `--commit`) | Play rejects the edit |
| 10 | report, plus the live Play state when API access exists | — |

The verified bundle is archived in `dist/android/<name>+<code>/` (gitignored) with its
SHA-256 and `release-summary.json`, which records the branch, commit and every
uncommitted file it was built from.

The draft release that `--upload --commit` creates still has to be reviewed and
rolled out in Play Console → Test and release → Testing → Closed testing.

## Play Developer API access (one-time)

The scripts authenticate as a **Google Cloud service account** that you invite into
Play Console with access to HimRaag only. It needs no Google Cloud IAM roles.

1. **Enable the API** in the Google Cloud project (`himraag-prod` is fine):
   Google Cloud console → APIs & Services → Library → **Google Play Android Developer API** → **Enable**
   (`https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=himraag-prod`).
2. **Create the service account:** IAM & Admin → Service accounts → **Create service account**.
   Name it `himraag-play-publisher`. Skip "Grant this service account access to project" (no roles), then **Done**.
   Its email is shown in the list, e.g. `himraag-play-publisher@himraag-prod.iam.gserviceaccount.com`.
3. **Create a key:** open the service account → **Keys** → **Add key** → **Create new key** → **JSON**.
   Move the downloaded file out of Downloads and lock it down:

   ```bash
   mkdir -p ~/.config/himraag
   mv ~/Downloads/himraag-prod-*.json ~/.config/himraag/play-publisher.json
   chmod 600 ~/.config/himraag/play-publisher.json
   ```

   Never put the key in this repository (it is public); `play_publish.mjs` refuses keys inside it.
   Another location works too: `export HIMRAAG_PLAY_SA_KEY=/path/to/key.json`.
4. **Invite it in Play Console:** Users and permissions → **Invite new users** → paste the service-account
   email → **App permissions** → **Add app** → HimRaag → tick only:
   - **View app information (read only)**
   - **Release apps to testing tracks**

   → **Apply** → leave **Account permissions** empty → **Invite user**.
5. **Verify:** `node scripts/release/play_publish.mjs status` lists the tracks and version codes.
   A `403` right after inviting usually means the invitation has not applied yet. Wait and retry.

Do not grant **Admin**, **Edit and delete draft apps**, financial or order permissions. Add
**Release to production, exclude devices and use Play app signing** only if you later decide that
production releases should go through the API (this workflow refuses production either way).

Revoke access at any time by removing the user in Play Console or deleting the key in Google Cloud.

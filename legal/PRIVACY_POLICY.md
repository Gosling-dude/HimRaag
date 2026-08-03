# Privacy Policy for HimRaag

**Last updated:** 3 August 2026
**Applies to:** HimRaag Android application (package `com.himraag.app`)

HimRaag ("we", "us") provides a streaming app for Pahadi folk and Himalayan
regional music. This policy explains exactly what we collect, why, and who it is
shared with. It describes the app as actually built — every item below
corresponds to a real data flow in the shipped application.

---

## 1. Who we are

HimRaag is operated by the HimRaag team.
Contact for privacy questions and data requests: **[INSERT CONTACT EMAIL]**

> **Action required before publishing:** replace `[INSERT CONTACT EMAIL]` with the
> address you enter in Play Console. The same address must appear here and in
> your store listing, or Google may reject the submission.

---

## 2. Using HimRaag without an account

You can browse and listen as a **guest**. In guest mode your preferences,
favourites and listening history are stored **only on your device** and are never
written to our servers. If you later sign in, the preferences held on the device
may be merged into your account.

---

## 3. Information we collect

### 3.1 Account information (only if you sign in)

When you sign in with Google, we receive and store:

| Data | Purpose |
|---|---|
| Email address | Identifying your account |
| Display name | Showing who is signed in |
| Profile photo URL | Showing your avatar |
| Google account identifier (UID) | Linking your data to your account |
| Sign-in method | Supporting the correct login flow |
| Account creation and last-seen timestamps | Account maintenance |

We request only basic profile and email scope. **We never receive your Google
password.** Authentication is handled entirely by Google.

### 3.2 Your music preferences and activity

Stored against your account so your library follows you between devices:

- Preferred regions, languages and genres
- Artists you follow
- Favourites
- Playlists you create
- Recently played tracks
- "Continue listening" position (track and playback position)
- Total play count

### 3.3 Downloads

Downloaded tracks are saved to **private storage inside the app's own folder** on
your device. They are not readable by other apps, are not uploaded anywhere, and
are deleted when you remove the download or uninstall the app.

### 3.4 Analytics and crash reporting

The app includes **Google Firebase Analytics** and **Firebase Crashlytics**.

Firebase Analytics automatically collects a standard set of app-usage data even
though we do not record custom events. This includes app opens, screen views,
session length, device model, operating system version, language, an
**approximate location derived from your IP address** (country/region level, not
precise location), and an advertising identifier.

Firebase Crashlytics collects diagnostic data **only when the app crashes**:
stack traces, the device model and OS version, and app state at the moment of the
crash. This is used solely to find and fix defects.

**We do not collect precise GPS location. We do not access your contacts,
microphone, camera, photos, SMS or call logs. The app requests no such
permissions.**

### 3.5 Content delivery

Audio files and artwork are served from **Cloudflare R2**. When your device
requests a track or an image, Cloudflare receives your IP address and standard
request headers, as is unavoidable for any internet content delivery. Cloudflare
processes this to deliver content and to protect against abuse.

---

## 4. Permissions the app requests, and why

| Permission | Why it is needed |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | Streaming music and checking connectivity |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Continuing playback when the app is in the background |
| `WAKE_LOCK` | Preventing the device sleeping mid-track |
| `POST_NOTIFICATIONS` | Showing the playback notification with track controls |

The app requests **no location, contacts, storage, camera or microphone
permissions.**

---

## 5. Legal bases for processing (UK/EU users)

- **Contract** — account data and your library, needed to provide the service you asked for.
- **Legitimate interests** — crash reporting and analytics, to keep the app stable and understand broad usage.
- **Consent** — where required by local law for analytics identifiers; you may withdraw it by uninstalling the app or contacting us.

---

## 6. Who we share data with

We **do not sell your personal data.** We do not share it with advertisers or
data brokers. Data is processed by these service providers only:

| Provider | Role | Policy |
|---|---|---|
| Google (Firebase Auth, Cloud Firestore, Analytics, Crashlytics) | Authentication, database, analytics, crash reporting | https://firebase.google.com/support/privacy |
| Cloudflare (R2) | Audio and image delivery | https://www.cloudflare.com/privacypolicy/ |

We may disclose data if legally required to do so.

---

## 7. Data retention

Account data is kept for as long as your account exists. If you request deletion,
we remove your account record and associated library data from our database.
Crash and analytics records are retained according to Google Firebase's standard
retention periods. Locally stored data (guest preferences, downloads, caches) is
removed when you uninstall the app.

---

## 8. Your rights

You may request **access to**, **correction of**, **export of**, or **deletion
of** your personal data by writing to **[INSERT CONTACT EMAIL]**. We respond
within 30 days.

**To delete your account and data:** contact us at the address above, or use the
in-app sign-out and uninstall to remove all locally held data. Account deletion
requests are processed within 30 days.

Depending on where you live you may also have the right to object to processing,
to restrict processing, or to lodge a complaint with your local data protection
authority.

---

## 9. Children's privacy

HimRaag is not directed at children under 13. We do not knowingly collect
personal data from children under 13. If you believe a child has provided us
data, contact us and we will delete it.

---

## 10. Security

Data in transit is encrypted with HTTPS/TLS; the app forbids cleartext traffic at
the platform level. Access to our database is restricted by server-side security
rules that limit each signed-in user to their own records. Administrative access
requires a separately granted privileged credential.

---

## 11. International transfers

Our providers (Google, Cloudflare) operate globally, so your data may be
processed outside your country, including in the United States. These providers
maintain their own safeguards for international transfers.

---

## 12. Changes to this policy

We will update the "Last updated" date above when this policy changes and, for
material changes, give notice in the app.

---

## 13. Contact

**[INSERT CONTACT EMAIL]**

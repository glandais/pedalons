# Data collection declarations — source of truth

Canonical record of what the **Pédalons mobile app** collects, and the exact answers to give in
each store's privacy form. Three artefacts must agree, and this file is the one they are derived
from:

| Artefact | Where | Kept in sync by |
|---|---|---|
| iOS privacy manifest | `mobile/ios/Runner/PrivacyInfo.xcprivacy` | hand-edit alongside this file |
| App Store Connect → App Privacy | `app-privacy.json` → `asc web privacy apply` | regenerate from §4 |
| Google Play Console → Data safety | `data-safety.csv` → `fastlane data_safety` | regenerate from §5 |
| Published privacy policy | `privacy/privacy-policy.{en,fr}.md` | must not contradict §2 |

- **App**: Pédalons, `fr.pedalons.mobile`, version `1.0.0+57` (`mobile/pubspec.yaml`)
- **Backend**: `https://www.pedalons.fr` (`mobile/lib/config/app_config.dart`)
- **Last verified against the code**: 2026-10-17 (route editor and GPX import, `MOB-79` —
  `lib/features/routes/`; before that 2026-09-27: problem reports and automatic error reports,
  `lib/features/feedback/`, `lib/core/logging/`, backend `FeedbackService`)

> Scope note. These declarations describe **the mobile app binary**, not the whole Pedalons
> platform. The web frontend can do considerably more than the app (see §7). Declaring platform
> capabilities the app does not have is as wrong as omitting ones it does.

---

## 1. What the app actually does

The mobile app authenticates, then reads team content — and, for a team's organizers, writes
its rides and routes (the ride editor, `MOB-76`, #21–#22; the route editor, `MOB-79`, #23). Four capabilities beyond reading touch
personal data: **picking a profile picture** from the photo library, **picking a document**
(a ride's attachments and a route's GPX file) with the system document picker, reading a **coarse
device position** to sort content by proximity, and registering the device for **push
notifications**. There is no camera capture and no analytics.

Since 2026-09-24 the app also lets a member **report** content or another member and **block**
another member (App Store guideline 1.2), and sign-up records that the **terms of service** were
accepted. It also writes **comments** (`lib/features/comments/`), which earlier revisions of this
file did not list; they are declared with the reports below, in the same bucket.

The capabilities added, and their exact boundary:

- **`image_picker`** — photo library only, to feed `POST /api/users/me/avatar` and, since
  `MOB-76` (2026-10-17), a ride's logo and images in the **ride editor** (organizers only,
  `POST /api/teams/{slug}/assets`, see #22). No camera
  capture (`NSCameraUsageDescription` is deliberately absent, so iOS cannot grant it).
  `NSPhotoLibraryUsageDescription` exists in `mobile/ios/Runner/Info.plist`, localized in
  `Runner/{en,fr}.lproj/InfoPlist.strings`.
- **`file_picker`** (2026-10-17, `MOB-76`, `MOB-79`) — the system document picker (Storage Access
  Framework on Android, `UIDocumentPickerViewController` on iOS), opened only by an organizer, for
  two things. *Add a file* in the ride editor uploads the file as a ride attachment
  (`POST /api/teams/{slug}/assets?assetType=ATTACHMENT`, #22). *Choose a GPX file* (or *Replace the
  GPX*) in the route editor picks the track of a route (`FilePicker.pickFile(type: FileType.any)`:
  `gpx` has no uniform type identifier on iOS), checked locally for a `.gpx` extension and an
  opening `<gpx` element before anything is sent (`lib/features/routes/domain/gpx_check.dart`).
  No storage permission is requested on either platform: the picker grants access to the one file
  picked.
- **GPX import** (2026-10-17, `MOB-79`) — the route editor (organizers and administrators of the
  team only, `lib/features/routes/presentation/pages/route_editor_page.dart`) sends the chosen file
  with `POST /api/teams/{slug}/routes` (creation) or `PUT …/routes/{routeSlug}` (when replacing the
  track), as the `gpxFile` part of a multipart request beside the route's name, description,
  surface, visibility and tags (#23). The exact boundary: the file is one the organizer chose to
  publish as a **team route** for the members to ride; the app never reads the device's position
  for it and draws or edits nothing on a map (the route planner stays on the web); and the
  **server** keeps only the track and its waypoints — timestamps, sensor measurements and the file's
  metadata are removed before anything is stored (`GpxSanitizer`; policy § *GPX files you import*).
- **`geolocator`** — `LocationAccuracy.low` only, while the app is in use. The coordinates become
  the `nearLat`/`nearLon`/`nearRadius` query parameters of an existing list endpoint and are never
  written to disk nor attached to the account. `NSLocationWhenInUseUsageDescription` (fr + en);
  Android requests **`ACCESS_COARSE_LOCATION` only** — `ACCESS_FINE_LOCATION` is still stripped
  with `tools:node="remove"` (see §5). No background location, no MapLibre user-location puck, no
  ride recording.

- **`firebase_core` + `firebase_messaging`** — Firebase Cloud Messaging, *messaging only*. The app
  sends the FCM registration token to `POST /api/push-devices` with the device name (the name the
  user gave the phone on iOS, manufacturer and model on Android) and the app version, and deletes it with `POST /api/push-devices/unregister` (the token in the body) on sign-out. Nothing else of
  Firebase is initialized: **no Analytics, no Crashlytics, no Performance, no Remote Config, no
  Installations-based measurement** — the Firebase project itself was created with Analytics
  switched off (`docs/LEDGER_*.md` NOTIF-9). The app asks for notification
  permission only from the notifications screen, never at launch. But where the system already
  allows notifications without a prompt (Android 12 and below, which have no runtime
  `POST_NOTIFICATIONS` permission), or where permission was granted earlier, the token is
  registered with our server automatically at every signed-in start
  (`lib/features/notifications/providers/push_provider.dart`, `_start`). Firebase itself is
  initialised at every launch, before sign-in (`lib/main.dart`), with FCM auto-init left at its
  default.
  `device_info_plus` is now on an executed path — it supplies that device name, and nothing else.

- **Reports and blocks** — `api.moderation` (`lib/api/generated/clients/moderation_client.dart`):
  `reportContent` → `POST /api/reports` with the team, the target, a reason from a fixed list and
  an **optional free-text message** (≤ 500 characters); `blockUser` / `unblockUser` →
  `PUT`/`DELETE /api/users/me/blocks/{userId}`; `listMyBlockedUsers` for the *Blocked users* page.
  Server-side the report also stores the target's author and a **copy of the reported text**
  (≤ 1,000 characters, `content_reports.excerpt`) and, later, the moderator's decision. The
  reporter's identity is readable by `PLATFORM_ADMIN` only. Nothing new is read from the device:
  no screenshot, no attachment, no contact.
- **Problem reports and automatic error reports** (2026-09-27) — `api.feedback`
  (`lib/api/generated/clients/feedback_client.dart`): `sendFeedback` → `POST /api/feedback` with a
  kind (bug / suggestion), the member's **free text** (10–5,000 characters) and, unless the member
  unticks "Attach technical information", a context (app version and build, OS, device model,
  current screen path, language, team slug), the error the sheet was opened from, and the in-app
  log (≤ 200 entries: navigations, failed requests as method + path + status + code, errors).
  `reportClientError` → `POST /api/feedback/errors`, sent **without user action** for an unhandled
  Dart error (type, message, stack) with the same context and the last 50 log entries — signed-in
  members only, never from debug builds, and switched off by *Profile → Preferences → Envoyer
  automatiquement les rapports d'erreur*. No SDK: our own endpoint. Server-side both are redacted
  (tokens, e-mail addresses) and published as issues of a **private GitHub repository** naming the
  member by id — GitHub is a sub-processor of the backend, not contacted by the app (§6). The log
  never holds query strings, request bodies or headers.
- **Terms acceptance** — `RegisterRequest.acceptTerms` (a required `true`); the server stores the
  timestamp in `users.terms_accepted_at`. A timestamp on the account, not a new data type.

Verified absent from `mobile/pubspec.yaml`, `mobile/pubspec.lock`, `mobile/lib/`, `mobile/ios/`
and `mobile/android/`:

- No `camera`, `photo_manager`, `image_cropper` — the media entry points are the system photo
  picker and, for ride attachments and the GPX of a route only, the system document picker
  (`file_picker`).
- No precise location, no background location, no `permission_handler` (permission prompts are
  `geolocator`'s own), and no MapLibre user-location layer.
- No FIT import, and no GPX import outside the route editor: the only file the app reads to send
  coordinates is the GPX an organizer picks to create or replace a team route (`MOB-79`, #23). No
  reading of the device's position for it, no recording of a ride, no track drawn or edited on a
  map. Everywhere else route files are download-only: fetched to `getTemporaryDirectory()` and
  handed to the OS share sheet (`lib/features/routes/presentation/widgets/route_download_actions.dart`).
  Coordinates flow server → device, except for that one organizer's GPX.
- No analytics, crash-reporting, advertising or attribution SDK (no Crashlytics/Sentry/Amplitude/
  AppsFlyer/Adjust). Crash reports exist since 2026-09-27, but through our own endpoint (#18),
  not an SDK. Firebase **is** present, but only `firebase_core` and `firebase_messaging` —
  see the push entry above; no other Firebase product is a dependency, which
  `grep -n "firebase" pubspec.yaml` shows: two dependency lines, the other two hits being
  comments. `ua_client_hints` remains a transitive
  dependency of `passkeys` and is on no executed code path; `device_info_plus` no longer is —
  it names the device at push registration.
- No StoreKit / `in_app_purchase` / payment SDK.
- The multipart / `FormData` uploads reachable from the UI are the avatar
  (`POST /api/users/me/avatar`), the ride and route editors' assets
  (`POST /api/teams/{slug}/assets`) and the creation and modification of a route with its GPX
  (`POST`/`PUT /api/teams/{slug}/routes`). Every other multipart operation in the generated client
  stays unreachable.

The generated client in `mobile/lib/api/generated/` mirrors the **entire** backend API (avatar
upload, post/comment/route CRUD, admin). Almost none of it is wired to UI — it is dead code and
must not be read as evidence of collection. See §7 for the trigger list.

---

## 2. Data inventory (evidence)

Everything below leaves the device to `https://www.pedalons.fr` unless stated otherwise.

| # | Data | Collected where | Off-device? | Linked to identity |
|---|---|---|---|---|
| 1 | **Email address** | Registration, login, forgot-password, reset-password forms — `lib/features/auth/presentation/pages/{login_page,forgot_password_page,reset_password_page}.dart` | Yes | Yes |
| 2 | **Password** | Same forms; `POST /api/auth/register`, `/login`, `/reset-password` | Yes (over TLS, hashed server-side) | Credential — see note |
| 3 | **Display name** | Registration only — `RegisterRequest(email, displayName, password, acceptTerms)`, `lib/features/auth/providers/auth_provider.dart` | Yes | Yes |
| 4 | **Account / user ID, session tokens** | `GET /api/users/me`, JWT subject, refresh token | Yes | Yes |
| 5 | **WebAuthn credential material** | `lib/features/auth/services/passkey_service.dart` — credential id, rawId, clientDataJSON, signature, userHandle, plus the literal device label `"Mobile"` | Yes | Yes |
| 6 | **Ride / trip / team participation** | Join & leave — `lib/features/rides/data/ride_repository.dart`, `lib/features/trips/data/trip_repository.dart`, `lib/features/teams/data/team_repository.dart`, called from `lib/features/teams/providers/{team_membership_controller,team_discovery_provider}.dart` | Yes | Yes |
| 7 | **GPS-device pairing code** | 6-character code — `lib/features/device/presentation/pages/device_verify_page.dart` | Yes | Yes |
| 8 | **Session security metadata** | Server-recorded on sign-in: IP address, user agent, last-login / last-use timestamps (per `privacy/privacy-policy.en.md` §"Session Data") | Yes | Yes |
| 9 | **Profile picture** | Photo chosen from the system photo library (`image_picker`) and sent to `POST /api/users/me/avatar` | Yes | Yes |
| 11 | **Push registration token** | `lib/features/notifications/providers/push_provider.dart` → `POST /api/push-devices`. Issued by FCM, identifies the *installation*, deleted server-side at sign-out and at account closure | Yes, to us **and to Google** (FCM issues it and routes every message) | Yes |
| 12 | **Device name and app version** | Sent alongside #11 (device name: the user-given name on iOS, manufacturer + model on Android) — `lib/features/notifications/data/push_device_repository.dart` (`device_info_plus`, `package_info_plus`) | Yes | Yes |
| 13 | **Comments** | `lib/features/comments/data/comment_repository.dart` → `create*Comment` on rides, trips, routes and posts | Yes | Yes |
| 14 | **Content reports** | Report sheet → `POST /api/reports`: target, reason, optional free-text message. Server adds the target's author, a copy of the reported text and the decision | Yes | Yes (reporter; erasure nulls it and keeps the report) |
| 15 | **User blocks** | `PUT`/`DELETE /api/users/me/blocks/{userId}`: who blocked whom, and when | Yes | Yes |
| 16 | **Terms acceptance** | Sign-up checkbox → `RegisterRequest.acceptTerms`; stored as `users.terms_accepted_at` | Yes | Yes |
| 17 | **Problem reports** | *Report a problem* sheet (`lib/features/feedback/presentation/feedback_sheet.dart`) → `POST /api/feedback`: kind, free text, optional error | Yes (then to GitHub, private repository) | Yes (user id; no e-mail) |
| 18 | **Crash data** | `lib/core/logging/error_reporter.dart` → `POST /api/feedback/errors`: unhandled error type, message, stack. Opt-out setting | Yes (then to GitHub) | Yes (user id) |
| 19 | **Diagnostics** | Sent with #17 (if ticked) and #18: app version, OS, device model, screen path, language, in-app log (`lib/core/logging/app_log.dart`) | Yes (then to GitHub) | Yes (user id) |
| 20 | **Message to an ad's author** | *Contact the seller* sheet (`lib/features/ads/presentation/widgets/ad_contact_sheet.dart`) → `lib/features/ads/data/ad_repository.dart` `contactAdAuthor`: free text, relayed by e-mail with the sender's address as Reply-To. The server keeps no body, only who wrote about which ad and when (`AdContact`, for rate limiting and abuse reports) | Yes (then to the author's inbox, through our e-mail provider) | Yes |
| 21 | **Rides written by organizers** | Ride editor (`lib/features/rides/presentation/pages/ride_editor_page.dart`) → `POST`/`PUT /api/teams/{slug}/rides`: name, markdown description, date, places, groups, chosen leaders. Organizers and administrators of the team only | Yes | Yes |
| 22 | **Ride images and attachments** | Same editor → `POST /api/teams/{slug}/assets`: a photo from the library (`image_picker`, logo and images) or any file from the document picker (`file_picker`, attachments) | Yes | Yes |
| 23 | **Routes written by organizers** | Route editor (`lib/features/routes/presentation/pages/route_editor_page.dart`) → `POST`/`PUT /api/teams/{slug}/routes`, multipart: name, markdown description, surface, visibility, tags, images and attachments through the path of #22, and the **GPX file** (`file_picker`) — its track and waypoints, the timestamps, sensor measurements and metadata being removed by the server before anything is stored. Organizers and administrators of the team only | Yes | Yes |
| 10 | **Approximate location** | `geolocator` at `LocationAccuracy.low`, while in use, only when the user turns on the "around me" filter — becomes the `nearLat`/`nearLon`/`nearRadius` query parameters | Yes, as query parameters of a read request | **No** — not stored server-side, not written to the account |

Stored **on device only**, never transmitted:

- `refresh_token` in the iOS Keychain / Android Keystore via `flutter_secure_storage`
  (`lib/features/auth/data/secure_storage.dart`), cleared on logout.
- Access token in memory only (`lib/api/pedalons_api_client.dart`), never persisted.
- UI locale via `shared_preferences` (written by `easy_localization`).
- The in-app log (`lib/core/logging/app_log.dart`): ≤ 200 entries in a JSONL file of the app
  support directory, so it survives a crash; the queued error reports and the last crash flag in
  `shared_preferences`. They leave the device only as #17–#19.
- Disk caches: downloaded avatars/images (`cached_network_image`) and temp GPX/FIT files —
  including the copy of the GPX that the system document picker hands the route editor (#23),
  which the app reads once for the local check and once for the upload, and never keeps elsewhere.

**Password note.** Neither store's form has a "password" data type. Apple's guidance is that
credentials are covered by the account data types already declared; Google's form likewise has no
password category. Passwords are therefore not a separate line item in §4/§5 — this is expected,
not an omission.

---

## 3. iOS privacy manifest

Mirrors `mobile/ios/Runner/PrivacyInfo.xcprivacy`. Values are the literal strings Apple accepts
(see *Describing data use in privacy manifests*); Xcode will not generate a privacy report if a
value is invented.

- `NSPrivacyTracking` = `false` — no tracking as ATT defines it.
- `NSPrivacyTrackingDomains` = empty — nothing to declare while tracking is false.

| `NSPrivacyCollectedDataType` | Linked | Tracking | Purposes | Covers |
|---|---|---|---|---|
| `NSPrivacyCollectedDataTypeEmailAddress` | `true` | `false` | `…PurposeAppFunctionality` | inventory #1 |
| `NSPrivacyCollectedDataTypeName` | `true` | `false` | `…PurposeAppFunctionality` | #3 |
| `NSPrivacyCollectedDataTypeUserID` | `true` | `false` | `…PurposeAppFunctionality` | #4, #5, #7 |
| `NSPrivacyCollectedDataTypeOtherUserContent` | `true` | `false` | `…PurposeAppFunctionality` | #6, #13, #14, #15, #20, #21, #22 (attachments), #23 |
| `NSPrivacyCollectedDataTypeOtherDataTypes` | `true` | `false` | `…PurposeAppFunctionality` | #8 |
| `NSPrivacyCollectedDataTypePhotosorVideos` | `true` | `false` | `…PurposeAppFunctionality` | #9, #22 (images) |
| `NSPrivacyCollectedDataTypeCoarseLocation` | **`false`** | `false` | `…PurposeAppFunctionality` | #10 |
| `NSPrivacyCollectedDataTypeDeviceID` | `true` | `false` | `…PurposeAppFunctionality` | #11, #12 |
| `NSPrivacyCollectedDataTypeCrashData` | `true` | `false` | `…PurposeAppFunctionality` | #18 |
| `NSPrivacyCollectedDataTypeOtherDiagnosticData` | `true` | `false` | `…PurposeAppFunctionality` | #19 |
| `NSPrivacyCollectedDataTypeCustomerSupport` | `true` | `false` | `…PurposeAppFunctionality` | #17 |

`…Purpose` above abbreviates `NSPrivacyCollectedDataTypePurpose`. Note the lowercase `or` in
`PhotosorVideos` — that is Apple's literal spelling, not a typo.

#23 (routes and their GPX) has no row of its own either: a route's name, description, tags and
attachments are *Other User Content* like the rides of #21, its images are *Photos or Videos* like
#22, and its GPX is covered in §4 (*GPX import adds no data type*).

#16 (terms acceptance) has no row of its own: it is a timestamp on the account created at sign-up,
covered by the account rows (`EmailAddress`, `Name`, `UserID`) like the account's creation date.

`CoarseLocation` is the only **unlinked** row: the coordinates travel as query parameters of a
read request and are never persisted against the account. Every other row is linked.

`Info.plist` carries the matching usage strings — `NSPhotoLibraryUsageDescription` and
`NSLocationWhenInUseUsageDescription`, plus `LSApplicationQueriesSchemes` (`webcal`, `mailto`,
`tel`) for `url_launcher`. The user-facing text is localized in
`ios/Runner/{en,fr}.lproj/InfoPlist.strings`; the values inline in `Info.plist` are the English
fallback and must stay in sync with `en.lproj`.

`NSPrivacyAccessedAPITypes` is unchanged and remains the standard Flutter set:
`UserDefaults` (`CA92.1`, `shared_preferences`), `FileTimestamp` (`C617.1`, `path_provider` /
`flutter_cache_manager`), `SystemBootTime` (`35F9.1`, elapsed-time measurement), `DiskSpace`
(`E174.1`, cache eviction).

Validate after editing:

```bash
plutil -lint mobile/ios/Runner/PrivacyInfo.xcprivacy
```

---

## 4. App Store Connect → App Privacy

Answer **"Yes, we collect data from this app"**, then declare exactly these eleven, none used for
**Tracking**, all purpose **App Functionality**. All are **Data Linked to You** except Coarse
Location, which is **Data Not Linked to You**:

| Category | Data type | Linked | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info | Email Address | Yes | No | App Functionality |
| Contact Info | Name | Yes | No | App Functionality |
| Identifiers | User ID | Yes | No | App Functionality |
| User Content | Other User Content | Yes | No | App Functionality |
| User Content | Photos or Videos | Yes | No | App Functionality |
| Location | Coarse Location | **No** | No | App Functionality |
| Identifiers | Device ID | Yes | No | App Functionality |
| Other Data | Other Data Types | Yes | No | App Functionality |
| Diagnostics | Crash Data | Yes | No | App Functionality |
| Diagnostics | Other Diagnostic Data | Yes | No | App Functionality |
| User Content | Customer Support | Yes | No | App Functionality |

*Crash Data*, *Other Diagnostic Data* and *Customer Support* (2026-09-27) are #18, #19 and #17.
Linked, because the server knows who sent them (the issue names a user id). *Customer Support* and
not *Other User Content*: a problem report is, in Apple's words, "data generated by the user
during a customer support request". The purpose is **App Functionality** — fixing the app's bugs —
and not *Analytics*: nothing is aggregated into usage metrics. `app-privacy.json` carries them as
`CRASH_DATA`, `OTHER_DIAGNOSTIC_DATA` and `CUSTOMER_SUPPORT`.

*Other Data Types* is the `OTHER_DATA` token in `app-privacy.json` (not `OTHER_DATA_TYPES`, which
`asc` rejects). If the form asks, describe it as: **"Session security metadata (IP address, user agent and
sign-in timestamps) recorded to detect suspicious account activity."**

*Other User Content* now also covers **comments, content reports and user blocks** (#13–#15). No new
data type was added, deliberately:

- A report is text the user writes (the optional message) plus a choice (reason, target) about
  content inside the app — Apple's *Other User Content* is "any other user-generated content",
  which is what it is. A block is a user choice recorded against the account, like the
  participation records the row already covers (Apple has no "actions" type).
- *Customer Support* was considered and rejected: a report is not a support request to us, it is
  routed to the team's organizers and handled in the app. *Product Interaction* is for analytics,
  which this is not. *Sensitive Info* does not apply: the reason list is fixed and describes the
  content, not the user.
- The purpose stays **App Functionality**: Apple's definition of it includes "implement security
  measures" and keeping the service safe, which is what moderation is. No data is used for
  anything else.

Consequently `app-privacy.json` is **unchanged** by the reporting feature: the `OTHER_USER_CONTENT`
entry it already carries is the right one.

**GPX import adds no data type** (2026-10-17, `MOB-79`, #23). The routes an organizer writes, and
the GPX file that gives one its track, are *Other User Content* — the row already declared, as for
a ride (#21) — and the route's images are *Photos or Videos* (#22). *Precise Location* was
considered and rejected, deliberately, against the trigger of §8. The file may well come from a
ride the organizer recorded (the screen suggests exporting it from a mapping tool or a bike
computer), but what the app does with it is publish it as a **team route** for the members: the
app reads no position from the device to produce it, and the server strips timestamps, sensor
measurements and the file's metadata before storing anything (`GpxSanitizer`, policy § *GPX files
you import*). What is collected is therefore a geometry, which no longer says *when* anyone was
*where* — neither a location history nor a log of movements. *Coarse Location* is untouched.
`app-privacy.json` is **unchanged**.

*Device ID* covers the **push registration token** and the device model sent with it (#11, #12) —
not an advertising identifier, which the app still never reads.

Explicitly answer **No / do not select**: Precise Location, Audio Data, Contacts, Health, Fitness,
Payment Info, Purchase History, Product Interaction, Advertising Data,
Performance Data, Search History, Browsing History.

Privacy policy URL: `https://www.pedalons.fr/privacy` (EN) · `https://www.pedalons.fr/confidentialite` (FR).

---

## 5. Google Play Console → Data safety

Same substance as §4, remapped to Google's taxonomy. The two taxonomies are not identical — the
divergences are called out below and are deliberate.

**Store-level answers**

| Question | Answer | Basis |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | §2 |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | HTTPS-only base URL; no `usesCleartextTraffic`, no `networkSecurityConfig`, no `NSAppTransportSecurity` exception |
| Do you provide a way for users to request that their data be deleted? | **Yes** | see below |
| Data deletion URL | `https://www.pedalons.fr/privacy` | Public page: policy §7 *Delete your account* gives the in-app and web steps and the e-mail fallback. Not `/profile`, which sits behind sign-in — a reviewer opening it lands on the login screen |
| Privacy policy URL | `https://www.pedalons.fr/privacy` | |

In-app deletion, which Play requires on top of the URL for apps that register accounts, exists:
**Profile → Account → Danger zone** (`lib/features/profile/presentation/widgets/data_and_account_section.dart`)
calls `DELETE /api/users/me`, then signs out.

**Per-data-type answers.** *Shared* = No on every row. *Collected* and *Processed ephemerally* are
per-row, because approximate location is the one type that is processed ephemerally.

| Category | Data type | Collected | Processed ephemerally | Required / optional | Purposes |
|---|---|---|---|---|---|
| Personal info | Name | Yes | No | Required | App functionality, Account management |
| Personal info | Email address | Yes | No | Required | App functionality, Account management |
| Personal info | User IDs | Yes | No | Required | App functionality, Account management, Fraud prevention, security, and compliance |
| App activity | Other actions | Yes | No | Optional | App functionality |
| App activity | Other user-generated content | Yes | No | Optional | App functionality, Fraud prevention, security, and compliance |
| Messages | Other in-app messages | Yes | No | Optional | App functionality |
| Photos and videos | Photos | Yes | No | Optional | App functionality |
| Files and docs | Files and docs | Yes | No | Optional | App functionality |
| Location | Approximate location | Yes | **Yes** | Optional | App functionality |
| Device or other IDs | Device or other IDs | Yes | No | Optional | App functionality |
| App info and performance | Crash logs | Yes | No | Optional | App functionality |
| App info and performance | Diagnostics | Yes | No | Optional | App functionality |

*Crash logs* (#18) and *Diagnostics* (#19) are **optional**: the automatic reports can be turned off
in the profile preferences, and a problem report's technical information is a ticked-by-default
checkbox. They are **not shared**: GitHub stores them as a service provider of ours, which Google
does not count as sharing. The report's free text (#17) is covered by the *Other user-generated
content* row already declared.

*Photos* is **optional**: the account works without a profile picture, and the photo library is
only reached when the user taps "change picture" — or, for an organizer, "add an image" or "choose
a logo" in the ride editor (#22).

*Files and docs* (2026-10-17, `MOB-76`, `MOB-79`) is **optional** and covers **ride attachments**
(#22) and the **GPX file of a route** (#23): an organizer picks a file with the system document
picker and it is uploaded to the team. Apple has no such type; on iOS the attachment and the GPX
are *Other User Content*. Nobody has to attach a file or create a route, and the file is **not
shared** beyond the service: it is shown to the ride's or the route's readers, inside the app. The
GPX adds no *Location* row: it is published as a team route and stored without timestamps, and
the app reads no device position for it (see §4, *GPX import adds no data type*, and §7).

*Approximate location* is **optional** and **processed ephemerally**: it is read only when the user
turns on the "around me" filter, sent as `nearLat`/`nearLon`/`nearRadius` on a read request, and
neither stored on the device nor persisted server-side. It is not linked to the account and is not
used for tracking or advertising. Precise location is **not** collected — the app requests
`ACCESS_COARSE_LOCATION` only, and `LocationAccuracy.low`.

*Other actions* covers participation (#6) and **user blocks** (#15): a block is a choice made in
the app, the same kind of record as a join/leave toggle.

*Other user-generated content* is **optional** and covers **comments** (#13), **content reports**
(#14) and **messages to an ad's author** (#20) — Google's example for the type is "open-ended responses", which is what a comment and a
report's free-text message are. Nobody has to comment or report to use the app. Its purposes are
*App functionality* and *Fraud prevention, security, and compliance*, the latter because a report
exists to enforce the terms of service. Reports are not *shared*: they go to the team's organizers
and to Pedalons inside the service, which Google does not count as sharing.

*Messages → Other in-app messages* is **optional** and covers the **message to an ad's author**
(#20) **as well as** the *Other user-generated content* row above (decided on 2026-09-29,
`docs/LEDGER_DONE.md LEGAL-7`): its full text goes from one member to another, which is what Google
calls a message, and declaring it twice costs nothing where declaring it too narrowly risks a
rejection. It is **not shared**: the relay is a transfer the sender initiates, and the e-mail
provider that carries it is a service provider of ours. Only the relay record is stored, not the
text.

*Device or other IDs* is **optional** and covers the **push registration token** (#11) with the
device model sent beside it: it exists only for a member who turned notifications on, and
sign-out deletes it. It is **not** an advertising ID — none is read — and Google's own form has no
finer bucket for a messaging token.

Everything else in the form is **not collected**: Precise location, Financial info, Health and
fitness, Emails, SMS or MMS, Videos, Audio files, Calendar, Contacts, App interactions,
In-app search history, Installed apps, Web browsing history, Other app performance data.

**Deliberate divergences from §4**

1. *Ride/trip/team participation* → Play **"App activity → Other actions"** (Google's example for that
   type is likes and dialog choices, which is what a join/leave toggle is), but Apple
   **"Other User Content"** (Apple has no "actions" type). Same underlying data, different bucket.
2. *Session security metadata* (#8) is declared to Apple under **Other Data Types** but has **no
   Play equivalent** — Google's form has no IP-address or user-agent type, and "Device or other
   IDs" means device-level identifiers such as an advertising ID, which the app does not collect.
   Not declaring it on Play is correct, not an omission.
3. *Approximate location* (#10) is declared to both, but Play additionally has a **"processed
   ephemerally"** flag, which we set. Apple has no such flag — the equivalent signal there is
   `NSPrivacyCollectedDataTypeLinked = false`. Same fact, two encodings.
4. *Comments, content reports and user blocks* (#13–#15) are all Apple **"Other User Content"**,
   but split on Play: blocks go with participation under **"App activity → Other actions"**, while
   comments and reports go under **"App activity → Other user-generated content"**, the bucket for
   free text. Play also gets the *Fraud prevention, security, and compliance* purpose, which Apple
   folds into *App Functionality*.

**There is no Android equivalent of `PrivacyInfo.xcprivacy`.** Google has no privacy-manifest file
that ships inside the APK/AAB — the Data safety declaration exists **only** as a Play Console web
form, which is exactly why §5 of this file exists. Nothing in `mobile/android/` encodes it, and
`fastlane`'s `upload_to_play_store` cannot upload it either. The Android Publisher API can
(`applications.dataSafety`, write-only), which is what the `data_safety` lane does with
`data-safety.csv` — see `README.md` in this folder.

What Android *does* encode is the **permission set**, and that must not contradict §5.

**Location permissions.** `mobile/android/app/src/main/AndroidManifest.xml` declares
`ACCESS_COARSE_LOCATION` and **only** that one, matching the *Approximate location / no precise
location* answer above.

`ACCESS_FINE_LOCATION` is still stripped with `tools:node="remove"`. It was never in our source
manifest — the merger injects it from `org.maplibre.gl:android-sdk-opengl:13.0.3-pre0`, pulled in
by the `maplibre` plugin (`build/app/outputs/logs/manifest-merger-release-report.txt:528-535`) for
its LocationComponent (the user-location puck), which this app never enables. `geolocator` does not
need it either: `LocationAccuracy.low` is served by the coarse permission. Left alone it would show
on the Play listing and over-declare against §5.

**Notification permission.** `POST_NOTIFICATIONS` (Android 13+) is declared and requested from the
notifications screen, never at launch. It is a permission, not a data type: Play's form has no row
for it, and the data it enables is declared as *Device or other IDs* above. The merge also brings in
`VIBRATE` and `WAKE_LOCK` from FCM and `flutter_local_notifications` — how a notification buzzes and
wakes the screen, not data, and not declarable.

Expected merged release permission set: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`,
`ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `VIBRATE`, `WAKE_LOCK`, `USE_BIOMETRIC`,
`USE_FINGERPRINT`, `USE_CREDENTIALS`, `CREDENTIAL_MANAGER_SET_ORIGIN` — and **no**
`ACCESS_FINE_LOCATION` (verified on the merged debug manifest, 21 September 2026). To re-check after a release
build:

```bash
# The FINAL merged manifest — not manifest-merger-release-report.txt, which keeps the rejected
# nodes in its decision log and so still mentions both permissions even when the strip worked.
grep -o 'android:name="android.permission.[A-Z_]*"' \
  mobile/build/app/intermediates/merged_manifest/release/*/AndroidManifest.xml | sort -u
```

The other merged permissions are not declarable data types and stay: `INTERNET`,
`ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` (MapLibre connectivity detection), `USE_BIOMETRIC`,
`USE_FINGERPRINT`, `USE_CREDENTIALS`, `CREDENTIAL_MANAGER_SET_ORIGIN` (passkeys), `VIBRATE` and
`WAKE_LOCK` (push).

Android needs no photo-library permission: `image_picker` goes through the system photo picker
(`ACTION_PICK_IMAGES` / `ACTION_GET_CONTENT`), which returns a single user-chosen item without
`READ_MEDIA_IMAGES`. Do not add that permission — it would over-declare.

---

## 6. Third parties contacted by the app

No SDK sends data to a third party other than FCM. **Map endpoints** outside our infrastructure
receive the device's IP address as an unavoidable consequence of an HTTP request. They are not
hard-coded in the app: the basemap list comes from `GET /api/config`
(`pedalons.map.*` in `backend/src/main/resources/application.properties`), so re-read that file
rather than this table when it changes.

| Endpoint | Why | What it sees |
|---|---|---|
| `tiles.versatiles.org` | Default basemap (style, vector tiles, glyphs, sprites) | IP address; the map viewport being browsed |
| `tiles.mapterhorn.com` | Relief shading (raster-DEM), when on | Same |
| `data.geopf.fr` (IGN Géoplateforme) | IGN, Satellite (IGN), SCAN 25 basemaps, when chosen | Same |
| `server.arcgisonline.com` (Esri, US) | Satellite (ESRI) basemap, when chosen | Same |
| `tile.openstreetmap.org` (OSMF, UK) | OpenStreetMap basemap, when chosen | Same |
| `*.tile-cyclosm.openstreetmap.fr` | CyclOSM basemap, when chosen | Same |
| Firebase Cloud Messaging (`*.googleapis.com`, APNs via Firebase) | Issues the registration token and routes every push (`lib/features/notifications/services/push_gateway.dart`) | IP address, the token it issued, the device and app version it registers, and **the content of each notification** — title and body are rendered server-side and travel through Google |

**GitHub is not contacted by the app.** Problem and error reports go to our backend, which
publishes them to a private GitHub repository: GitHub is a sub-processor of the *backend*, named in
the privacy policy (§4 and the US transfer in §5), not a third party of the app binary.

FCM is a genuine **sub-processor**: it does not merely see an IP address, it carries the message.
The map providers are independent controllers of a request the device makes; none receives an
account identifier. Both are in the published policy since 2026-09-21 (§4 *Technical service
providers* and *Basemaps*, §5 for the US and UK transfers).

**No font is fetched.** Inter is bundled (`assets/fonts/inter/`, declared in `pubspec.yaml`) since
2026-09-21; `google_fonts`, which pulled it from `fonts.gstatic.com` at first launch, is no longer
a dependency. Do not bring it back — it would re-open a US transfer for a typeface.

---

## 7. Not declared, and why

| Not declared | Why |
|---|---|
| Precise Location | Only `ACCESS_COARSE_LOCATION` is requested and only `LocationAccuracy.low` is used; `ACCESS_FINE_LOCATION` is stripped from the merged manifest. No background location, no ride recording, no user-location puck. Route coordinates are **downloaded** for display; describing where a *route* is is not describing where the *user* is. **The GPX an organizer imports (`MOB-79`, #23) does not change that**: the file may come from a ride the organizer recorded, but it is published as a team route for the members, the app reads no device position to produce it, and the server keeps only the geometry — timestamps, sensor measurements and file metadata are removed before storing (`GpxSanitizer`, policy § *GPX files you import*) — so what is collected is neither a location history nor a log of movements. |
| Videos | `image_picker` is restricted to still images (`pickImage`) for the avatar and a ride's logo and images; no video is ever read. |
| Camera | No `NSCameraUsageDescription` and no camera permission — the photo library is the only entry point. |
| Fitness / Health | No HealthKit, no Motion & Fitness, no activity recording. |
| Advertising ID | No advertising identifier is read or sent. The declared *Device ID* row covers the FCM registration token only (#11). The passkey `deviceName` is still the constant string `"Mobile"`. |
| Product Interaction / Usage / Advertising Data | No analytics or advertising SDK of any kind. |
| Performance Data | Nothing measured: no timings, no frame stats. (Crash Data *is* declared since 2026-09-27, #18.) |
| Purchase History / Payment Info | No purchases in the app. |
| Emails or Text Messages, Contacts, Audio, Search History, Browsing History | No corresponding capability. |

---

## 8. Update triggers

Re-run the audit and update **this file, the manifest, and both store forms together** when any of
these ships:

| If the app gains… | Add |
|---|---|
| Profile editing (`PUT /api/users/me`) | nothing new — Name/Email already declared |
| Camera capture for the avatar | `NSCameraUsageDescription` in `Info.plist` (+ its two `InfoPlist.strings`); no new data type — Photos or Videos already covers it |
| Post authoring (comments are already declared, #13; ride authoring since `MOB-76`, #21–#22; route authoring since `MOB-79`, #23) | nothing new — Apple `NSPrivacyCollectedDataTypeOtherUserContent` and Play *Other user-generated content* are both declared; widen the manifest comment and §2 |
| A screenshot or attachment on a report, or automatic moderation of images or text beyond the word filter | Apple `…PhotosorVideos` already covers images, but re-read §4 for the purpose; Play *Photos*; any third-party moderation service is a new sub-processor for the policy |
| GPX **import** from the device | Delivered by `MOB-79` for a team route an organizer publishes (#23): Play *Files and docs* and Apple `…OtherUserContent`, both declared; no Precise Location: the file may come from a recorded ride, but it is published as a route for the members, no device position is read and the server keeps only the geometry (timestamps, sensor data and metadata are stripped before storing). **Precise Location (Apple `…PreciseLocation`, Play *Location → Precise location*) becomes due** if the app imports **activities** as the user's own history, if the server starts keeping timestamps, or if the app records a ride. Any other import (FIT, a GPX outside the route editor) is a new audit |
| Live location / "record a ride" / follow-me on the map / a MapLibre user-location puck | Apple `NSPrivacyCollectedDataTypePreciseLocation` (and flip Coarse Location's `Linked` if it becomes persisted); Play *Location → Precise location* and drop the *processed ephemerally* flag; stop stripping `ACCESS_FINE_LOCATION`; `NSLocationAlwaysAndWhenInUseUsageDescription` if it ever runs in the background |
| Storing the user's position server-side (saved "home area", proximity history) | flip Apple `NSPrivacyCollectedDataTypeCoarseLocation` → `Linked: true` and clear Play's *processed ephemerally* |
| Any other Firebase product (Analytics, Crashlytics, Remote Config, In-App Messaging) | It is no longer "no Firebase, full stop": re-read §1, and expect Apple `…ProductInteraction` / `…CrashData` and Play *App info and performance* to become due |
| Any analytics or crash SDK | Apple `…ProductInteraction` / `…CrashData` (+ re-check `NSPrivacyTracking` and `NSPrivacyTrackingDomains`); Play *App info and performance*, *App activity → App interactions* |
| In-app purchases | Apple `…PurchaseHistory` / `…PaymentInfo`; Play *Financial info* |

**Known open items** (not store declarations — tracked here so they are not lost):

1. ~~**In-app account deletion**~~ Done — it shipped with the settings-style profile
   (`fce64d47`); the deletion URL now points at the public policy rather than the signed-in
   profile. (§5)
2. ~~**The privacy policy has not caught up with §2 #9 and #10.**~~ Done 2026-09-21: the policy
   says the app receives only the photo picked through the system picker, and gained an
   *Approximate location* subsection (read on demand, in use only, sent as a search parameter,
   not stored with the account — and, honestly, present in the web server's access log like any
   request URL) plus a consent-based purpose.
3. ~~**The privacy policy says nothing about push.**~~ Done 2026-09-21: `privacy/privacy-policy.{en,fr}.md`
   gained a *Notifications* subsection (inbox, preferences, delivery records, phone registration,
   opt-in and sign-out deletion), FCM (Google Ireland) in the provider table, the US transfer and
   its safeguards, the 90-day retention, and the export contents. The e-mail provider's row (Brevo then, Scaleway
   Transactional Email since 2026-09-22) now says it carries notification content, not just an address.
4. ~~**Undisclosed third-party endpoints.**~~ Done 2026-09-21: Inter is bundled and `google_fonts`
   removed; every basemap provider is listed in the policy with what it sees, and the Esri (US)
   and OSMF (UK) transfers are stated. (§6)
5. ~~**`android:allowBackup` is unset**~~ Done 2026-09-21: `allowBackup="false"`,
   `fullBackupContent="false"`, and `res/xml/data_extraction_rules.xml` excluding every domain from
   both cloud backup and device-to-device transfer — `allowBackup` alone no longer stops the
   latter on Android 12+. Nothing reaches Google Drive, and a new phone signs in again, which it
   had to anyway since the restored `refresh_token` was undecryptable.
6. ~~**Account deletion is a flag, never a purge.**~~ Done 2026-09-21: `deleteUser` now erases
   synchronously (`AccountErasureService`), and `AccountErasureScheduler` catches up nightly on
   accounts flagged before. The `users` row is anonymized, not deleted — ~30 foreign keys hold team
   content — and everything personal goes: credentials, memberships, future registrations, ads,
   comments (an answered one stays as a blank tombstone), notifications, exports, GPX previews,
   avatar. Rides, routes and posts created for a team stay, credited to "Ancien membre", which
   the policy's "Delete your account" section now states, along with the 30-day backup window.

7. **Reports and blocks** (2026-09-24): declared as above; the policy gained a *Reports and
   blocks* subsection (what is kept, the reporter visible to Pedalons only, team moderators seeing
   content and reason but not the reporter, the blocked person never told, the publication filter
   storing nothing), the terms-acceptance timestamp, retention rows, the export contents and what
   erasure does (blocks deleted both ways, reports about the user deleted, reports by the user kept
   without the reporter).
9. **Problem reports and error reports** (2026-09-27): declared as above (#17–#19); the policy
   gained a *Problem reports and error reports* subsection, GitHub in the provider table and the
   US transfers, retention rows (reports 1 year, error reports 90 days) and the localStorage key of
   the web opt-out. The mobile opt-out lives in `shared_preferences`.
8. **The inventory lagged the code elsewhere** (2026-09-29). The re-verify loop below also lists
   `uploadRoute` and `contactAdAuthor` as reachable from the UI. `uploadRoute` has nothing to
   declare: it asks the server to send a route it already holds to the connected GPS service
   (`serviceType`, `teamSlug`, `routeSlug`), no file leaves the device
   (`lib/features/routes/presentation/widgets/route_download_actions.dart`). `contactAdAuthor` is
   now #20, under the *Other User Content* / *Other user-generated content* rows already
   declared — and, on Play only, under *Messages → Other in-app messages* too (`LEGAL-7`).

---

## How to re-verify

```bash
cd mobile

# capability negatives — these should still print nothing
grep -rnE "^ *camera:|photo_manager|image_cropper|permission_handler" pubspec.yaml
grep -rn "NSCameraUsageDescription\|LocationAlways" ios/Runner/Info.plist
grep -rn "READ_MEDIA_IMAGES\|ACCESS_BACKGROUND_LOCATION" android/app/src/main/AndroidManifest.xml

# capability positives — exactly two usage descriptions, in three files that must agree
grep -rn "UsageDescription" ios/Runner/Info.plist ios/Runner/en.lproj/InfoPlist.strings \
  ios/Runner/fr.lproj/InfoPlist.strings

# location must stay coarse and foreground-only
grep -rn "ACCESS_.*_LOCATION" android/app/src/main/AndroidManifest.xml
grep -rniE "LocationAccuracy|getCurrentPosition|getPositionStream" lib | grep -v lib/api/generated

# uploads: only the avatar, the editors' assets and a route's GPX should show up outside the
# generated client (the route editor's repository, route_repository.dart, builds the GPX part).
# auth_interceptor.dart also matches: it clones a FormData before replaying a request after a 401
# (retryableOptions), it sends nothing new.
grep -rn "MultipartFile\|FormData" lib | grep -v lib/api/generated

# file_picker: exactly two calls — the ride editor's attachments (#22) and a route's GPX (#23)
grep -rn "FilePicker\." lib

# Every mutating operation the app can actually reach, to confirm §2 is still complete.
# App code calls generated retrofit clients, so grepping for `.post(` in lib/ finds almost
# nothing — resolve the @POST/@PUT/@PATCH/@DELETE method names first, then see which are referenced.
grep -rhA3 "@\(POST\|PUT\|PATCH\|DELETE\)(" lib/api/generated \
  | grep -oE "Future<[^>]*> [a-zA-Z0-9_]+\(" \
  | sed -E 's/.*> ([a-zA-Z0-9_]+)\(/\1/' | sort -u \
  | while read -r m; do
      grep -rqE "\.${m}\(" lib/features lib/core && echo "USED: $m"
    done

# the route editor's mutations (#23) — createRoute/updateRoute are in the loop above; the editor
# page reaches them through route_repository.dart
grep -rnE "\.(createRoute|updateRoute)\(" lib/features lib/core

# push stays messaging-only: exactly firebase_core and firebase_messaging, nothing else
grep -n "firebase" pubspec.yaml
# no font is fetched from Google: must stay empty
grep -n "google_fonts" pubspec.yaml

# reports and blocks: the calls behind §2 #14 and #15, and nothing that reads a file or the camera
grep -rnE "\.(reportContent|blockUser|unblockUser|listMyBlockedUsers)\(" lib/features lib/core

# the notification permission must be asked from a screen, never at launch
grep -rn "requestAuthorization" lib | grep -v lib/api/generated

# problem / error reports: the two calls behind §2 #17–#19
grep -rnE "\.(sendFeedback|reportClientError)\(" lib/features lib/core

# manifest is well-formed
plutil -lint ios/Runner/PrivacyInfo.xcprivacy
```

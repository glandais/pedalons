# Privacy Improvement Opportunities — 2026-07-25

> **Tracking moved to the ledger (2026-09-29).** What is still open here is followed under
> `SEC-7`, `SEC-12` (Karoo token store), `SEC-17` and `WEB-28` in `docs/LEDGER_NEXT.md`; this
> file keeps the options and their rationale. #5 and #6 are done (`LEGAL-9`). #3 is moot (`LEGAL-1`), #27 is moot (the dump import is
> gone), #15's acceptance trail shipped with the moderation work; #16, #17 and #19 were decided under `LEGAL-13`
> (single controller, breach paragraph, age declared in the terms checkbox; no admin access log: `LEGAL-16`).

Companion to [2026-07-25-privacy-policy-audit.md](archive/2026-07-25-privacy-policy-audit.md). The audit fixed the
*documentation*; this report lists opportunities to improve the *product* so users' privacy actually gets
better — and so several uncomfortable disclosures added to the policy can be deleted again. Each item names
the code touchpoints and, where relevant, the policy text it would allow simplifying.

Refreshed on 2026-09-21 against develop (see
[2026-09-21-privacy-policy-refresh.md](archive/2026-09-21-privacy-policy-refresh.md)): done items are struck
through with a **Done** note, and #20–#27 are new.

Legend: **[GDPR]** = compliance obligation or strong expectation · **[Minimize]** = data minimisation /
privacy by design · **[Harden]** = security of personal data · **[Trust]** = transparency & user control.

---

## P0 — Compliance gaps to close first

### 1. Real account erasure (GDPR Art. 17) **[GDPR]**
Today `UserService.deleteUser()` (backend/src/main/java/fr/pedalons/service/user/UserService.java:75) only
sets `deleted=true`. Nothing is ever purged; email, password hash, passkeys, GPS OAuth tokens, calendar
token and sessions all survive account closure, and re-registration with the same email needs manual help.
- In the closure transaction: revoke all sessions, delete passkeys, GPS connections (and remotely revoke
  their OAuth tokens where the provider API allows), calendar tokens, Strava identity links.
- Add a scheduled purge/anonymisation of accounts deactivated more than N days ago (30 is the number the
  old policy promised). Anonymisation option: replace displayName with "Deleted account", null email/avatar,
  keep authored content intact for the team.
- Decide content fate: purge or keep-anonymised (policy currently says keep-anonymised on request).
- Then rewrite: policy §6 "Account closure" paragraph and its TODO; terms §8; and the frontend/mobile UI
  strings that today over-promise ("Permanently delete your account and all associated data" —
  frontend/src/locales/*/common.json:488-492, 862-866 — are **false today**; fix the strings now even
  before the purge job exists).

> **Done (fe4f39b5):** `UserService.deleteUser()` now calls `AccountErasureService.erase()`
> synchronously — sessions, tokens, passkeys, calendar token, GPS and Strava links, memberships,
> upcoming registrations, comments (tombstone kept for an answered root), ads (soft-deleted, blanked,
> photos removed), ad-contact records, notifications, push devices, exports, GPX previews and avatar
> are deleted; the `users` row is anonymised ("Ancien membre", `<id>@erased.invalid`), team content
> stays credited to it. `AccountErasureScheduler` catches up nightly. Policy §6/§7 and terms §8
> rewritten on rebase. Still open: GPS OAuth grants are not revoked at the provider.

### ~~2. Fix the iOS privacy manifest and store data-safety declarations~~ **[GDPR]** **[Trust]**
> **Done (d0705864, 0bd0db44)** in the repo: `PrivacyInfo.xcprivacy` declares EmailAddress, Name,
> DeviceID (push), UserID, OtherUserContent, PhotosorVideos, CoarseLocation (not linked) and
> OtherDataTypes — all linked except location, no tracking, app functionality — and
> `mobile/store-metadata/data-safety.md` is the source of truth for both store forms; the
> `ACCESS_FINE_LOCATION` MapLibre pulls in is stripped from the merged manifest. Remaining: copy it
> into the App Store / Play web forms (not checkable from code), fix the location wording (#7) and the
> account-deletion answers (#14). `data-safety.md` §1 also overstated when the push token is
> registered — corrected on 2026-09-21 (Android 12 and below register without a prompt; see #23).

`mobile/ios/Runner/PrivacyInfo.xcprivacy` declares an **empty** `NSPrivacyCollectedDataTypes` while the app
handles email, name, photos, user content and location-bearing GPX data. App Review can reject for this,
and it contradicts the policy. Declare the collected data types (and fill the Play Data Safety form with
the same answers; keep a source-of-truth file in the repo, e.g. under `mobile/store-metadata/`).

### 3. Art. 14 notice for Biketeam-imported members **[GDPR]**
Members were imported (some without email, with Strava/Facebook/Google identifiers) and Art. 14 requires
informing them within a month of obtaining data indirectly. For members with a real email: send a one-off
notice. For placeholder-email accounts: show an in-app notice on first Strava login. Record the import date
and legal basis in the policy TODOs (privacy-policy §1/§2 comments).

### ~~4. Data export / portability endpoint (Art. 15 & 20)~~ **[GDPR]** **[Trust]**
> **Done (71af8eae, 1c03fec7, fce64d47)**: self-service export shipped — a queued ZIP job, a download
> link emailed and valid 7 days, one request per hour per account, available on the web
> (Profile → Your data) and in the mobile app. Remaining gaps: see #22.

No export exists anywhere (`api/users` has only me/avatar/search/delete). A self-service
`GET /api/users/me/export` returning a ZIP (JSON of account, memberships, participations, content; original
uploaded files; GPX/FIT) turns a manual 30-day DSAR into a button. It also gives the DSAR channel an
identity check for free (the user must be signed in). Until then, keep the manual-process wording added
to policy §7.

---

## P1 — High-value data minimisation (each deletes a scary disclosure)

### ~~5. Strip EXIF on image upload~~ **[Minimize]** — *first P1 item*
> **Done (2026-09-29, `API-43`):** `S3StorageService.store` has imgproxy re-encode every image
> (JPEG/PNG/WebP/GIF keep their format; TIFF, HEIF/HEIC/AVIF and JXL become JPEG; JP2 is refused),
> which leaves no metadata, and a backfill (V47 `metadata_pending`) re-encodes the originals already
> stored. Policy §1 now says the metadata is removed and the image re-encoded. Videos, documents
> and SVG/ICO are still stored as-is (`API-46` to `API-48`).

> **2026-09-21:** more urgent than it was. An ad's location is now blurred to about 1 km and the
> proximity probe is quantised (`common/CoarseLocation.java`, `AdRepository`), because an ad's location
> is in practice the seller's home — but photos attached to an ad are exposed to every team member as
> original files (`AssetService` builds `AssetDto.url` → `/api/download/…/assets/…`,
> `AbstractDownloadAssetResource.downloadAsset`), EXIF GPS included, which undoes the blur; the mobile
> app now also offers the original for download (4d82d193). At minimum strip EXIF on ad images, or stop
> exposing the original-file URL for ad photos and serve only the imgproxy variants (check that
> `IMGPROXY_STRIP_METADATA` stays at its default `true` — docker-compose.yml does not set it). Policy §1
> now warns about ad photos specifically.

Photos are stored byte-for-byte, so camera GPS positions, timestamps and device models are redistributed to
anyone allowed to view them. Strip EXIF (keep orientation) at upload in the asset service. Then replace the
long EXIF warning in policy §1 "Photos and images" with "we remove this metadata on upload".

### ~~6. Strip `<time>` and sensor extensions from imported GPX/FIT~~ **[Minimize]**
> **Done (2026-09-29, `API-44`):** `GpxSanitizer` in `GpxProcessingService.computeGpx` keeps only
> lat/lon/ele and waypoint position/name for every route and GPX-tool file (original, filtered, FIT);
> `GpxSanitizationBackfill` rewrote the stored ones. The health-data paragraph left policy §1. A
> GPX/FIT uploaded as a plain attachment is not cleaned (`API-49`).

Activity exports carry per-point timestamps, heart rate (health data — Art. 9!), cadence, power. The
platform never uses them but stores and re-serves them. Strip `gpxtpx` extensions and timestamps at import
(both team routes and the GPX tool). Deletes the health-data paragraph from policy §1.

### 7. Stop leaking GPS coordinates (Garmin and mobile) into server logs **[Minimize]**
The Garmin app sends current position as `lat`/`lon` query parameters, so real-time positions end up in
access logs. Move them to a header or POST body; configure log retention (see #13). Simplifies the
"Server logs" bullet in policy §1.
> **2026-09-21:** now also the mobile app. "Around me" sends raw `nearLat`/`nearLon` doubles as GET
> query parameters on every route-list request while the filter is on
> (`mobile/lib/features/routes/data/route_repository.dart:40-41`, no rounding in
> `routes_near_me_controls.dart`), and Traefik's access log (`docker-compose.yml` `--accesslog`)
> records the full URL next to the client IP. The iOS usage strings ("never stored or shared") and the
> "processed ephemerally / not linked" store answers are true of the database, not of the logs. Fix:
> round on the client to a coarse grid (~1 km, the grid ads already use) and move the values out of the
> query string, or drop query strings from the access log. Also fix `data-safety.md` §1 "Coordinates
> flow server → device, never device → server", which contradicts its own row #10, and the iOS strings
> that mention "rides and routes" (only routes use location).

### 8. Bundle the mobile font — drop the Google transfer **[Minimize]**
`mobile/lib/core/theme/pedalons_theme.dart` uses `GoogleFonts.interTextTheme()` with no bundled font, so
first launch sends the device IP to fonts.gstatic.com (US). Add Inter to `pubspec.yaml` `fonts:` and set
`GoogleFonts.config.allowRuntimeFetching = false`. Deletes the Google Fonts row from policy §4 and the
transfer bullet from §5. The web app already bundles the font — this is mobile-only. Trivial fix.
> **2026-09-21:** still open — only a dependency bump (69c2e955, `google_fonts ^8.2.1`), no `fonts:`
> section, no `allowRuntimeFetching`. Note that with Firebase Cloud Messaging now in the app, bundling
> the font no longer removes Google from policy §5 on its own; that also needs Firebase deferred (#23).
> **Done (develop, before the rebase):** Inter 4.1 bundled under `mobile/assets/fonts/inter/`,
> `google_fonts` dropped from `pubspec.yaml`. Google Fonts row (§4) and transfer bullet (§5) removed.

### 9. Self-host or proxy map/geocoding third parties **[Minimize]**
Browser-side requests to VersaTiles, OSM/CyclOSM, Esri (US), Mapterhorn and Nominatim expose visitor IPs +
viewed areas (and typed place names to Nominatim), including on public pages viewed by non-users. The stack
already runs a tileserver and Varnish: (a) proxy/cache the popular EU styles through it; (b) self-host
Nominatim or proxy geocoding server-side (`frontend/src/components/common/GeocoderAutocomplete.tsx`);
(c) consider dropping the Esri style or gating it behind an "external content" confirmation. Also confirm
Mapterhorn's hosting country (server-side elevation correction already only sends coarse tiles).
Each provider removed simplifies policy §4/§5 and strengthens the §8 no-consent-needed reasoning.
> **2026-09-21:** ~~(b)~~ **Done (b379128c)** — geocoding goes through `GET /api/geocode/search`
> (`NominatimLookup`, 24 h in-memory cache) and no longer leaves the browser. Follow-up:
> `NominatimLookup.java:47` writes the typed (normalised) query to the server log when a lookup fails —
> drop that value from the log line or mention it in the server-log paragraph.
> **2026-10-17:** geocoding now goes to Stadia Maps' EU host (ledger `OPS-49`), and the free-roaming
> maps gained a search bar that queries Stadia Maps from the browser (`WEB-99`, declared in policy
> §4/§5, `LEGAL-24`) — a new browser-side third party, the reverse of (b). The log follow-up still
> holds: the class is now `GeocodingLookup` (`fr.pedalons.infrastructure.stadiamaps`), same line. (a) still open, but now
> much easier: the server already generates the style document of every raster basemap (OSM, CyclOSM,
> Esri, IGN satellite, SCAN 25, Michelin — `MapStyleService.generatedStyle`, served by
> `MapStyleResource` at `/api/map/styles/{id}.json`, 4488bd52 / 24eb2632); pointing its `raster.tiles`
> at a caching tile proxy on our own origin (the existing Varnish) would stop devices contacting those
> providers. Only the hosted vector styles (VersaTiles, IGN vector) and the Mapterhorn DEM would still
> go out directly. Each basemap moved removes a §4 row, and Esri removes the §5 US bullet (check each
> provider's tile-usage terms first). (c) still open: Esri is still offered with no confirmation, now in
> the mobile app too. New: say who runs `tiles.pedalons.fr` (Michelin basemap) — policy TODO.

---

## P2 — Hardening stored secrets & sessions

### 10. Hash the calendar token; revoke it on account closure **[Harden]**
`CalendarToken` is stored cleartext (it must be looked up from the URL — store SHA-256 of it instead and
hash the incoming value). Add rotation UI if missing, and revoke on account closure (see #1). Removes one
of the two hashing exceptions from policy §9.
> **Revocation part done (fe4f39b5):** account erasure deletes the calendar token. Hashing still open.

### 11. Encrypt the Karoo token store **[Harden]**
`karoo/.../auth/AuthManager.kt` keeps access/refresh tokens in plain DataStore. Use encrypted DataStore or
Keystore-wrapped values. (Garmin Connect IQ storage has no such option — sandbox-only is the honest story
there.) Softens the "not additionally encrypted by us" disclosure in policy §1.

### 12. Real brute-force protection on login **[Harden]** — *OTP part raised to P0*
> **2026-09-21:** see docs/SECURITY_AUDIT.md H1 (high: unlimited OTP verification — `AuthService.verifyOtp`
> has no failed-attempt counter and the code stays valid after a wrong guess, which allows taking over
> any account, platform admin included) and M4 (medium: no password throttling). Fix: count failed OTP
> attempts on the token, persisted in a separate transaction so the failure is not rolled back;
> invalidate the code after N failures; add per-IP rate limiting on `/api/auth/*` (e.g. a Traefik
> `rateLimit` middleware).

Only OTP/email-token *issuance* is throttled (AuthService, DB-count based). Password, OTP-verify and
passkey endpoints have no per-IP/per-account limiter. Add throttling/lockout (bucket4j, or a Caffeine
counter keyed by IP+account) on `POST /auth/login`-family endpoints. Then policy §9 can honestly say
"rate limiting against brute force" again.

### 13. Nightly cleanup coverage + log retention **[Harden]** **[GDPR]**
`AuthCleanupScheduler` misses: expired `DeviceCode`s never claimed, abandoned `WebAuthnChallenge`s, used
Strava `SocialLoginCode`s. Add them to the 03:00 job — three repository deletes. Configure host log
rotation with a stated period (e.g. 30 days) and put that number in policy §1/§6 (two TODOs today).
Also confirm the backup volume is encrypted at rest — the nightly snapshot contains the JWT signing keys
and the GPS-token encryption key alongside all personal data.

---

## P3 — Transparency & governance

### 14. Align in-app strings with reality **[Trust]**
The delete-account and delete-team dialogs promise permanent deletion of "all associated data" — false
until #1 ships. Sweep `frontend/src/locales/*/common.json` and `mobile/assets/l10n/` for privacy claims and
align them with the policy (or with the new purge behaviour once built).
> **2026-09-21 — concrete list.** Until #1 ships, fix: `mobile/assets/l10n/en.json` / `fr.json`
> `profile.account.deleteMessage` ("This cannot be undone. Your registrations, your comments and your
> profile will be permanently deleted." / "…seront définitivement supprimés.") and
> `profile.account.dangerHint`, both added with the new in-app deletion (fce64d47); and
> `frontend/src/locales/*/common.json` `profile.account.dangerZone.deleteDescription` ("Permanently
> delete your account and all associated data."). Suggested: "Your account will be deactivated. To have
> your data permanently erased, write to privacy@pedalons.fr." In `mobile/store-metadata/data-safety.md`
> §5, close the "Open item" about the missing in-app deletion path (it exists now: Profile → Delete the
> account), and note that Google Play's account-deletion policy expects associated data to be deleted
> or the retained data disclosed — the "Yes, users can request deletion" answer depends on #1 or on
> disclosing what is kept.

### 15. Terms/policy acceptance trail & change notification **[Trust]** **[GDPR]**
Policy §11 promises email/in-app notification of significant changes, but no notification mechanism exists
and no acceptance is recorded (no terms-version field on User). Minimal version: a `policy_version` column,
a login interstitial when it changes, and a Brevo template for the email. Also consider rendering the
"Last updated" date from a single source instead of hardcoding it in four markdown files.
> **2026-09-21:** a notification mechanism now exists (inbox, e-mail through the Brevo `notification`
> template, push — eca2a3fe, e241d921). What remains is a `POLICY_UPDATED` notification (domain-wide
> rather than team-scoped, with an e-mail that cannot be switched off) plus the acceptance record.
> Policy §11 was softened to "by email" until then. Also add a one-click unsubscribe (List-Unsubscribe
> header or signed link) to notification e-mails: today the only way out is the preferences page
> (`NotificationLinks.PREFERENCES_PATH` = `/profile#notifications`), which requires signing in;
> `grep unsubscribe backend/src/main` finds nothing.

### 16. Controller identity vs multi-tenancy **[GDPR]**
Every tenant domain serves the same hardcoded policy naming Gabriel Landais as controller. If other clubs
run on their own domains, decide the controller/processor split (Pedalons as processor for the club, or
joint controllers) and make §12 per-domain (fields on the `Domain` entity + templated legal page).

### 17. Breach-response and admin-access commitments **[Trust]**
Policy §9 has no Art. 33/34 breach-notification commitment and platform-admin access is not logged. Add an
audit log for admin reads of user data (then say so in §4), and a short incident-response paragraph in §9
("we will notify the CNIL within 72 h and affected users without undue delay").

### 18. Single-source the legal texts **[Trust]**
Two live copies exist: `privacy/*.md` (bundled into the Flutter app) and `frontend/src/assets/legal/*.md`
(web, synced by `pnpm copy-legal`). Nothing enforces equality. *(2026-09-21: `mobile/privacy` is a
symlink to `../privacy`, so the mobile app always ships the canonical files; only the gitignored web
copy can drift.)* Add a CI check (`diff -r`) or make the build
copy from `privacy/` automatically, so web and mobile can never ship diverging policies.

### 19. Age handling (§10 / terms §3) **[GDPR]**
"16+" is stated but nothing asks or records age, in a youth-heavy cycling context where team admins can
enroll accounts and anyone signed-in can search profiles. Minimum: a self-declaration checkbox at
registration ("I am 16 or older") with a stored timestamp. Anything more (birthdate) would itself be new
data collection — weigh carefully.

---

## New since 2026-07-25 (added 2026-09-21)

### 20. Push device lifecycle **[Harden]** **[Minimize]**
`AuthService.logoutAll()` and `UserService.deleteUser()` leave `push_devices` rows in place, the client
unregisters only its own token (`mobile/lib/features/auth/providers/auth_provider.dart`), and
`PushDeviceRepository` deletes only by user+token or by tokens FCM rejects — there is no inactivity
purge (V39 has `last_seen_at`, no expiry). Delete the user's rows in `logoutAll()`, on session
revocation and in account closure (#1), and purge devices whose `last_seen_at` is older than N days
(e.g. 90; the app refreshes it at every launch). A lost or signed-out phone then stops showing team
names, member names, ride titles and reply extracts on its lock screen, and the policy §6 row can give a
real period instead of "not removed after a period of inactivity".

> **Partly done (1a5af242):** account closure now erases the user's push devices, inbox, deliveries
> and notification settings (`NotificationService.forgetUser`). Still open: `logoutAll()` leaves
> other devices registered, and there is no inactivity purge. Account deletion now goes through
> `AccountErasureService` (fe4f39b5), which keeps calling `forgetUser`.

### 21. Revoke the server session on GPS-device sign-out **[Harden]**
The Garmin "Log out" entry (`garmin-app/source/HomeMenuDelegate.mc:93-99` → `AuthManager.clearTokens`)
and the Karoo disconnect (`karoo/.../MainActivity.kt:552-558` → `AuthManager.clearTokens`) only wipe
local storage, leaving the 90-day device session alive. Call `POST /api/auth/logout` with the stored
`X-Refresh-Token` (the endpoint already accepts it) best-effort before clearing. Then policy §1/§6 can
say that signing out on the device ends the session. Consider a per-session list in the profile
(device, last use) with individual revocation — today only "Sign out of every device" exists, and only
in the mobile app (the website has no such button).

### 22. Keep the DSAR export complete **[GDPR]**
`UserExportBuilder` (lines 153-183) has no section for notifications (inbox, read dates),
notification preferences, push devices (platform, device name, app version, dates — token withheld as
credential material), team invitations sent and received, or ad-contact records; and
`AccountExport.Profile` omits `timezone` and `contactableByMembers`. Add them, and add a test that fails
when a table referencing `users` is neither mapped to an export section nor explicitly excluded, so the
export does not drift again. Then delete the "does not yet include" sentence from policy §7.

> **Partly done (1a5af242):** the export now carries `notifications/inbox.json` (with each entry's
> e-mail/push deliveries), `account/notification-preferences.json` and `account/push-devices.json`
> (token withheld). Still missing: time zone, ad-contact flag, invitations, ad-contact records — and
> the drift test.

### 23. Do not start Firebase before push is wanted **[Minimize]**
`mobile/lib/main.dart:28-36` initialises Firebase before the first frame on every launch, with FCM
auto-init left at its default, so every launch — including before sign-in — contacts Google (a US
transfer policy §5 now has to disclose for people who never use push). And on Android 12 and below
`push_provider.dart` `_start` registers the token at every signed-in start without any prompt, because
the OS reports notifications as authorised. Set `firebase_messaging_auto_init_enabled=false`
(Android meta-data) and `FirebaseMessagingAutoInitEnabled=NO` (iOS Info.plist), move
`Firebase.initializeApp()`/`getToken()` behind an explicit in-app opt-in, and only then register.

### 24. Minimise push content **[Minimize]**
`COMMENT_REPLY` puts `{actor}` and the reply `{excerpt}` in the push title/body
(`notifications/texts_*.properties`), which transit through Google/Apple and show on lock screens
(`FcmClient` sets no Android visibility). Drop the excerpt (and possibly the actor) from the push, or
send a generic `New reply on "<title>"` and let the app fetch details; set Android visibility to
private with a redacted public version. Also send the iOS model identifier instead of the user-assigned
device name (`push_device_repository.dart` uses `iosInfo.name`, often "<First name>'s iPhone").

### ~~25. Keep push tokens out of access logs~~ **[Harden]**
> **Done (2026-09-30, `API-45`; 2026-10-01, `API-56`):** `POST /api/push-devices/unregister` carries
> the token in the body (the export link moved to `?token=` too); the former path forms were removed
> from the API in 10.0.0.

`DELETE /api/push-devices/{token}` (`PushDeviceResource.java:59-78`) carries the FCM token in the URL
path, so it lands in the Traefik access log (`docker-compose.yml` `--accesslog.filepath`). Move it to a
request body (or `POST …/unregister`).

### 26. Retention for invitations, ad contacts and beta sign-ups **[GDPR]** **[Minimize]**
(a) Team invitations: terminal rows — including unaccepted ones holding a non-user's address — are kept
365 days (`TeamInvitationScheduler`, `retention-days=365`). Once an invitation expires or is revoked
unaccepted, erase or hash the email; for accepted rows `accepted_by` already identifies the person.
Add a privacy-policy link and a "decline" action to the invitation e-mail and page: the e-mail says
"simply ignore this email", but the address stays for up to 14+365 days and `InvitationResource` offers
only preview/accept. (b) `ad_contacts` has no purge (only `AdService` uses `AdContactRepository`): delete
rows after e.g. 90 days — they serve only the 60-minute rate limit and abuse follow-up. (c) Beta
sign-ups: moot — the form, its table and the policy's paragraphs were removed on 2026-10-25 (ledger
`API-142`).

### 27. Biketeam import must not publish e-mail addresses as names **[Minimize]**
`BiketeamMigrationService.displayNameFor` (806-811) falls back to the account's e-mail address (real,
or the `strava_`/`facebook_`/`google_` placeholder) when the first and last names are empty, and
display names are shown to the whole team and publicly on public content. Use a neutral fallback
("Member" + short id) and fix already-imported rows where `display_name = email`. Related: `createUser`
ignores `bt.deletion()`, so an account deleted on Biketeam is imported active on a first run (only
`updateUser` applies it) — policy §1 carries a TODO.

---

## Suggested order of attack

| Wave | Items | Rationale |
|------|-------|-----------|
| 1 (this week) | #8 font bundling, #14 UI strings, #13 cleanup jobs, #2 iOS manifest | Small, mechanical, high embarrassment-value |
| 2 | #1 erasure pipeline, #10 calendar token, #12 rate limiting | The GDPR core; unlocks removing ~6 policy TODOs |
| 3 | #5 EXIF, #6 GPX sensors, #7 Garmin logs, #4 export endpoint | Minimisation + portability |
| 4 | #9 map proxying, #15–#19 governance | Larger/structural |
| 5 (added 2026-09-21) | #12 OTP counter (now P0), #20 push lifecycle, #21 device logout, #25 token in URL, #27 display-name fallback | Small backend changes, each deletes a policy caveat |
| 6 | #22 export completeness, #23 Firebase deferral, #24 push content, #26 retention rules | Unblocks deleting the new §5/§6/§7 caveats |

After each wave, delete the corresponding `<!-- TODO(owner) -->` comments from `privacy/*.md`, simplify the
affected sections, bump the "Last updated" date, and re-run `pnpm copy-legal`.

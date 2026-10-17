# Mobile end-to-end tests (Patrol)

[Patrol](https://patrol.leancode.co) drives the real app on the iOS simulator or an Android emulator against the **e2e
stack** — the same one as the web suite (`frontend/e2e/`): empty database, mail to mailpit only.
Nothing is mocked: accounts are created through the REST API and verified with the link read from
mailpit.

## Running

```bash
flutter pub global activate patrol_cli          # once; add ~/.pub-cache/bin to PATH
../scripts/e2e.sh up                             # from mobile/: start the e2e stack
bash e2e.sh                                      # every test
bash e2e.sh -t patrol_test/logout_test.dart      # one test (any `patrol test` flag passes through)
```

`e2e.sh` reads the ports from `../.env.e2e`, passes them as dart-defines, and runs on the simulator
named "iPhone 17 Pro Max" (or the UDID in `PATROL_DEVICE`). **Never run a bare `patrol test`**:
the app's `API_BASE_URL` defaults to production, and `E2eConfig` refuses to start a test whose API
is not on `localhost`.

`patrol test` **uninstalls the app from the simulator** after the run, `fr.pedalons.mobile`
included — reinstall your dev build afterwards. `flutter test` does not run these files; they
only run through Patrol.

### On Android

```bash
<sdk>/emulator/emulator -avd <avd> -no-snapshot-save &   # one emulator
E2E_PLATFORM=android bash e2e.sh -t patrol_test/logout_test.dart
```

Give the AVD **4 cores** and turn Digital Wellbeing off. With 2 cores and 2 GB, a whole-suite run
saturates the emulator: a system ANR (« Digital Wellbeing », « System UI ») covers the app,
`ride_participants_map_test` fails on `no share sheet`, the chooser opens late and stays in front,
and the instrumentation never resumes — Back and « Wait » do not unblock it; kill the run. Seen
twice (2026-10-01 and 2026-10-02); the same tests pass alone and on 4 cores.

`<sdk>` is `$ANDROID_HOME`; without it, `e2e.sh` looks for adb where Android Studio installs the SDK:
`~/Library/Android/sdk` on macOS, `~/Android/Sdk` on Linux.

`E2E_PLATFORM=android` runs on `emulator-5554` (or the adb serial in `PATROL_DEVICE`) and never
touches a simulator, so it runs beside an iOS run on the same stack — the tests seed under unique
names. Don't `reset`, `down` or `build` the stack while the other one runs. The app keeps
`API_BASE_URL=http://localhost:…`: `e2e.sh` waits for the boot to complete, then `adb reverse`s the
stack's HTTP and mailpit ports. Plain HTTP to `localhost` is allowed by
`android/app/src/debug/res/xml/network_security_config.xml`, debug builds only.

### From an agent (Patrol MCP)

`../.mcp.json` registers a `patrol` server (`tool/patrol_mcp.sh`, the `patrol_mcp` package): an
agent can `run` a test file in a `patrol develop` session, take a `screenshot`, read the
`native-tree`, then `quit`. It uses the same stack, device and dart-defines as `e2e.sh` — both
source `tool/e2e_env.sh` — so the stack must be up first. Set `SHOW_TERMINAL=true` in its `env` to
follow the session's logs in a Terminal window, `E2E_PLATFORM=android` to drive the emulator.

Native wiring: the `RunnerUITests` target in `ios/Runner.xcodeproj`; on Android the
`PatrolJUnitRunner` with the test orchestrator (`android/app/build.gradle.kts`) and
`android/app/src/androidTest/…/MainActivityTest.java`.

## Layout

Follows LeanCode's architecture (the `patrol-test-architecture` skill):

- one test per `*_test.dart` file, each going through `testApp` (`common.dart`), which hands it
  the `modules` and the `apiClients`;
- `openApp($)` mounts the app as a fresh install (keychain and preferences cleared — they outlive
  the app between tests), `openAppSignedIn($, user)` with the user's session already stored;
- `modules/` — one class per feature as the user sees it (`auth`, `navigation`, `profile`); a test
  calls module methods only, never Patrol finders;
- `api/` — `BackendClient` (seeds through the API, each test under a unique name: the database is
  shared with the web suite and never reset) and `MailpitClient`;
- widgets are found **by key only**. Keys live in a `keys.dart` next to their feature
  (`lib/features/auth/keys.dart`, …) and are aggregated in `lib/keys.dart`; add one only for a
  widget a test uses.

Helpers of `common.dart` beyond mounting the app:

- `openLink($, path)` opens an app path as a shared link or a push notification does — through
  `pendingPushRouteProvider`, the same waiting logic as a web link, ancestors rebuilt underneath.
  That is how a test reaches a ride, a post or `/karoo?code=…` without walking the UI to it;
- `eventually(read, until: …)` polls the API for what the backend does on its own schedule (the
  notification dispatcher runs every 15 s);
- `openApp`/`openAppSignedIn` may be called twice in a test (a second user, a relaunch): the
  previous app is unmounted first, its `ProviderScope` and cache with it;
- `testAppKnownDefect(…, defect: …)` is Playwright's `test.fail`: the body describes the fixed
  app, fails today for the documented defect, and the wrapper passes. The day the defect is fixed
  the wrapper fails and asks for `testApp` back — never loosen the assertions instead. It only
  catches what the body throws: a defect the app reports through `FlutterError` (a debug
  assertion, a layout overflow) fails the test whatever the wrapper.

A ride or a trip opened from the home or by `openLink` is pushed above the tab shell: there is no
tab bar to tap until it is gone. `openLink($, Paths.home())` then `Home.waitUntilShown()` brings
the tabs back.

`Module.scrolledTo(key)` needs its widget hit-testable at its centre; a section whose middle is
empty (a short comment's row, a wrap of badges) goes through `scrolledIntoView(key)`, or through a
button inside it.

The platform admin (the stack's `PEDALONS_BOOTSTRAP_ADMIN_EMAIL`) seeds what only it may do: add
members, open a team to the public, make it joinable. It logs in by OTP, rate-limited to 3 per
5 minutes, so `BackendClient.admin()` keeps its refresh token in the app's temporary directory for
the rest of the run — writing back the rotated one after each refresh: the old one, presented once
its grace is over, revokes the session and costs an OTP.

## Coverage

Transposed from the P0 of [`docs/plans/archive/2026-09-27-e2e-coverage-audit.md`](../../docs/plans/archive/2026-09-27-e2e-coverage-audit.md)
to what the app does — it reads and takes part, it doesn't edit, and it has no server rendering:

| Audit P0 | Test |
|---|---|
| #1, #9 — denied roles, private team | `private_team_test` — a members-only team stays out of discovery; its ride and team links show an error to an outsider. `load_error_delay_test`: that error shows within 10 s — a 4xx is never retried (`providerRetry` on the app's `ProviderScope`) |
| #2 — joining a team | `team_join_test` (join, then leave), `team_invite_only_test` (« Sur invitation », disabled) |
| #3 — leader who left the team | `ride_leader_test` — the group still names its leader, never the ride's creator; joining, then switching groups through the exclusivity banner |
| #4 — ad rights | `ad_rights_test` (a non-author may contact, report, block — never delete), `ad_author_test` |
| #5 — notifications | `notification_post_test` (bell badge, entry in the team's name, opens the post, reads it), `notification_mute_test` (a team switched off in the profile's « Notifications »), `notification_settings_test` (the chips of a type are the channels the server declares — none on the e2e stack, no « Résumé quotidien par e-mail » without `EMAIL`; a chip writes its own cell; « Ouvrir mes notifications » and the inbox's settings button lead to one another) |
| #6 — moderation | `report_post_test` (report from the post, three reports hide it), `block_user_test` (block a comment's author, unblock from the profile's « Confidentialité ») |
| #7 — slug change | `slug_change_test` — links under the old team and ride slugs; a member opening the team by its old slug is offered « Quitter » (the page moves onto the current slug, one membership state) |
| #8 — device pairing | `device_link_test` (`/karoo?code=`, then the Hammerhead step — ledger `API-63`), `device_hammerhead_test` (the Karoo's fallback `/karoo/hammerhead`, a refused OAuth back on `/karoo?gps_error=`), `device_manual_code_test` (unknown code, « Réessayer », lowercase), `device_link_signed_out_test` (a link opened signed out survives the login: the device is paired once signed in) |

Beyond the P0 — the P1/P2 of the audit and the app's own screens. A **[known defect]** test would
be a `testAppKnownDefect`, pinning a defect of the app with the evidence in its doc comment; none is
left today.

| Scenario | Test |
|---|---|
| Rides — « Complet » (`rides.e2e.ts` › registration) | `ride_group_full_rollback_test` — a group that fills up while the page is open: the optimistic join is rolled back, the banner names that group and outlives the refetch, the card says « Complet », the other group still takes the rider |
| Rides — the editor (`flow-rides.e2e.ts` › an organizer creates, edits, publishes, deletes; ledger `MOB-76`) | `ride_editor_test` — an organizer creates a draft on a route picked in the sheet, renames it from the ride page's pencil (the API keeps the group's id), publishes it and deletes it from « Gérer la sortie ». `ride_editor_member_test` — a plain member gets no pencil and a refusal from the editor link. Not covered: the photo library, the document picker, the zone from a start place; the template flow is `ride_templates_test` |
| Rides — templates (`flow-rides.e2e.ts` › ride templates, web `RideTemplate*`; ledger `MOB-78`) | `ride_templates_test` — an organizer opens « Gérer les modèles » from the team dashboard, creates a template from the empty list (number 41, group renamed, 12 seats), edits its number from the `⋯` menu (the API keeps the group's id), creates a ride from it (titled « Name #50 », the template's `nextNumber` moves to 51), then deletes it after confirmation. `ride_templates_member_test` — a plain member gets a refusal from the list link and from the new template link. **Written, not yet run** (ledger `MOB-77`) |
| Audit P2 — « Quitter » from « Ma prochaine sortie » | `next_ride_card_test` — the home card follows a leave from its own button and a join from the ride page |
| Trips — join, leave (`flow-trips.e2e.ts`) | `trip_join_leave_test` — a trip that started yesterday is still open: join (participants name the member), stage card, stages rail, « Aperçu », leave; cancelled behind the app, a pull-to-refresh shows « Voyage annulé » and no action bar |
| Trips — a stage's thread (`flow-trips.e2e.ts` › a member comments on a stage; ledger `API-11`) | `stage_comments_test` — a comment sent from screen 25 lands in the stage's own thread, never the trip's nor the other stage's; `COMMENT_ON_MY_PUBLICATION` reaches the trip's author with the trip as its subject |
| Dates — the user's timezone (`flow-account.e2e.ts` › timezone picker; ledger `API-15`) | `user_timezone_test` — a member whose preference is `Pacific/Auckland` reads a stage set at 08:00 Paris at its own time, with their Auckland time in the mention — both formatted by `AppFormatters.formatTime`, since the device's 12/24 h setting decides the shape |
| Profile — time zone picker (`flow-account.e2e.ts` › timezone picker) | `profile_timezone_test` — « Préférences » › « Fuseau horaire »: « Fuseau de l'appareil » until chosen; « auckland » searched in the sheet, `Pacific/Auckland` picked, shown on the row and kept by `/api/users/me` |
| P1 — comments | `comment_reply_test` — comment from the composer, reply nested under a teammate's comment (no third level), delete one's own, a third party's comment offers report/block but no delete; `COMMENT_REPLY` to the commenter, `COMMENT_ON_MY_PUBLICATION` (never `COMMENT_REPLY`) to the post's author |
| P1 — invitations | `team_invitation_accept_test` — the `TEAM_INVITATION` entry opens « Mes équipes », whose pending card accepts it: the team joins the list, the invitation leaves the API |
| P1 — notifications | `notifications_unread_filter_test` — « Non lues » lists unread entries only; « Tout marquer lu » empties it (its empty state, « Toutes » as the way out) and the bell |
| P1 — team pages | `team_pages_visibility_test` — members read TEAM and PUBLIC pages; an outsider of a public team only sees the PUBLIC one (`TeamDetailDto.pages` is filtered by the same rule as reading a page) |
| Account — sign-up (`flow-account.e2e.ts`) | `sign_up_terms_test` — terms unticked: inline error and no mail; ticked: back to the login with the address filled in, the verification mail leaves, no sign-in before it is followed. |
| Account — e-mail verification (`flow-account.e2e.ts`) | `sign_up_verify_test` — the same form, then the link read from mailpit, opened as a mail link: the page signs the rider in, the password works from then on |
| Account — forgotten password | `password_reset_test` — a link opened while signed out is kept; « Mot de passe oublié ? » → mailed link → new password → signed in on that post; old password refused. The link replayed after logout shows « Lien invalide »; « Demander un nouveau lien » with an unknown address shows the same screen and sends no mail |
| Account — deletion | `account_deletion_test` — sole admin of a team with a member: blocked banner names the team, no confirmation. Once alone: the sheet names the team, confirming signs out, the login and another session are refused, the public team answers 404, and the login form refuses the address |
| Profile — participations | `profile_participations_list_test` (a ride joined in the app is listed under « Mes sorties » › « À venir » and opens from there); `profile_participations_count_test` — the badge of the overview's « Mes sorties » counts a registration made in the app |
| Ads — location (`ads-browse.e2e.ts` › location map) | `ad_location_map_test` — an ad with a place: « Localisation », its description, the « approximative » caption, a sector over a still map that draws no point (no waypoint, start, end or overlay), centred on the blurred cell within ~1 km of the seeded point and not on it; an ad without a place has no location header, map nor sector |
| Ads — contacting the seller (`ad-contact.e2e.ts`) | `ad_contact_test` — 9, 2001 and ten blank characters keep « Envoyer » off, 10 and 2000 turn it on; sent: the sheet closes, a confirmation replaces the button; one relayed mail, the draft in it, `Reply-To` the buyer, `From` not the buyer, neither address in its body; the ad's API answer carries no seller address. `ad_contact_opted_out_test` — seller not contactable: `AD_CONTACT_OPTED_OUT` closes the sheet, a notice replaces the button, nothing mailed. `ad_contact_rate_limited_test` — ten messages spent through the API: the eleventh shows « Réessayez dans 1 heure » (`Retry-After` 3600), keeps the draft, « Réessayer » enabled, the page keeps its button, the seller got ten mails |
| Rides — past and cancelled (`rides.e2e.ts` › a past ride, `flow-rides.e2e.ts` › cancellation) | `ride_past_cancelled_test` — a ride of yesterday, still `PUBLISHED`, says « Terminée » and none of its two groups offers « Rejoindre », « Quitter » or « Complet »; a ride cancelled behind the app shows its banner, and its single group (the detail's action bar, ledger `MOB-69`) offers nothing — not even « Quitter » to a rider the API still counts as registered |
| P1 — a 5xx is not a « not found » (`error-states.e2e.ts`) | `load_error_retry_test` — a 500 on the team, then on the ride (made by `server_errors.dart`, an interceptor the test adds to the app's `Dio`, as the web suite's `page.route`): retried three times (≥ 3 s, four requests), then the page's error — the ride's reads « Erreur de chargement », not « introuvable »; once the server answers again, « Réessayer » loads the page |
| P1 — ride notifications (`flow-notifications.e2e.ts` › personal notifications) | `notification_ride_cancelled_test` — a ride cancelled by its organiser: `RIDE_CANCELLED` reaches the registered rider, never the member who wasn't registered; its entry reads « Une sortie est annulée » and the ride's name, and opens the ride under its « annulée » banner |
| P1 — ride notifications, the joined rider (`flow-notifications.e2e.ts`)| `notification_ride_joined_test` — a rider joins from the app: `RIDE_JOINED`, naming the rider and carrying the group as its excerpt, reaches the ride's creator **and** the group's leader (`RideGroupDto.leader`, not the creator), never the rider; the leader's entry names the rider and the group, and opens the ride, whose card names the leader |
| Routes (`flow-routes.e2e.ts` › platform list, « Utilisée dans ») | `routes_visibility_test` — a signed-in outsider searching the Parcours tab finds a public team's public route, never its members-only one nor a private team's; the list/map toggle keeps the search; the route's page draws its elevation profile (from the stored GPX) and « Utilisée dans » lists the public ride alone. A member finds both of the team's routes; a surface filter narrows the list, one nothing matches ends on the filtered dead end; « Utilisée dans » adds the members-only ride and the trip (« via l'étape … ») |
| Team tags (ledger `MOB-39`; `tags.e2e.ts` does it on ads, by URL) | `team_tags_filter_test` — a team with two `ROUTE` tags and a route under each: a member's team route list shows the first tag on the first card, not on the second; the « Tags » chip, that tag ticked and « Appliquer », keeps the first route alone (`?tags=`) |
| Calendar (`calendar.e2e.ts`) | `calendar_test` — the Calendrier tab shows the rides of both of the member's teams, never a public team's public ride; each card names its team, « Inscrit · Groupe A » on the joined one only; a card opens its ride. The team's section shows that team alone; « Copier le lien » puts the team feed URL (`teamFeedUrlTemplate` with the slug) on the clipboard, « Régénérer le lien » replaces the token and the next copy hands out the new URL |
| Profile — settings (`flow-account.e2e.ts`) | `profile_preferences_test` — one sub-page after the other from the overview: display name saved (« Mon compte »); « Être contacté » off (« Confidentialité »); imperial units (the example turns to miles); dark theme (the app redraws dark); English (the language row says « English »), then back to French: all reach `/api/users/me`, and with the switch off the relay refuses a buyer `AD_CONTACT_OPTED_OUT` |
| Profile — data export (`flow-account.e2e.ts` › personal data export) | `profile_data_export_test` — « Jamais demandé », « Demander mes données » → « En préparation… »; the scheduler's mail carries a download link; back in « Confidentialité » the card says « Prêt » and the API `READY` |
| Profile — sign out everywhere | `profile_logout_all_test` — « Connexion et sécurité » › « Déconnecter tous les appareils » + confirmation: back to the login, this device's and another device's refresh tokens refused, the password still signs in |
| Session — a refused access token (no web counterpart) | `expired_access_token_test` — the running app's access token swapped for one the server refuses: the profile's participation count still loads with a fresh token, and « Déconnecter tous les appareils » reaches the server (another device's session ends) |
| Moderation — reports beyond posts (`flow-moderation.e2e.ts`) | `report_details_test` — a member reports a ride, a trip, a route and an ad from their `⋯`: each page closes behind its report and the team's moderator finds each in the open queue. `report_members_test` — the same from the « Membres » list (the menu also offers to block) and from a ride's participants sheet, the report naming the member |
| Moderation — a moderator's delete (`flow-moderation.e2e.ts`) | `comment_moderator_delete_test` — an organizer's `⋯` on a member's comment offers « Supprimer » (and « Signaler »); the comment leaves the thread and the API |
| Lists — feeds (`pagination.e2e.ts`, `list-filters.e2e.ts`) | `feed_pagination_test` — 21 posts and a ride in a team of its own: scrolling the team feed reaches the entry the API puts on page 2; « Sorties » keeps the ride alone, « Articles » the posts alone; a search that matches nothing shows the filtered empty state; the home feed reaches its page 2 as well |
| Lists — ads and members (`pagination.e2e.ts`, `list-filters.e2e.ts`, `member-directory.e2e.ts`) | `ads_members_pagination_test` — 22 ads and 22 members: both lists reach their page 2 by scrolling; the « Recherche » chip keeps the wanted ad alone, a search that matches nothing ends on the ads' dead end; the members search narrows the list to one name |
| Lists — comments (`rides.e2e.ts` › comments) | `comments_pagination_test` — a thread of 21 comments: scrolling the post reaches the 21st, on the API's page 2 (the thread loads its next page as its foot nears the screen) |
| Rides — single-group ride (ledger `MOB-69`, web `WEB-79`) | `ride_solo_group_test` — a ride with one group has no group card: « Rejoindre » then « Quitter » from the detail's action bar, checked against the API; the group's own link (`…/groupes/{id}`) opens the ride's detail, not a group page |
| Rides — participants, groups map, exports (no single web counterpart) | `ride_participants_map_test` — « Voir la liste » gathers the riders of both groups (count 2, one row each, not the reader nor the creator); the groups map's pill names the first group, then the one whose card is tapped; the card's « GPX » (and « FIT » when the route has one) follows the route's assets, no « Envoyer vers un appareil » without a connected GPS service, and « GPX » opens the system share sheet on a GPX file (native tree) |
| Apps — beta sign-up (`flow-platform-admin.e2e.ts` › beta sign-ups) | `apps_beta_signup_test` — from the profile's « Aide et à propos » › « Applications »: a malformed address stays on the form with « Adresse e-mail invalide »; a good one shows « Inscription enregistrée »; the same address in capitals, from a fresh page, answers the same; the admin list holds it once |
| Legal pages (`routes-render.e2e.ts` › terms, privacy) | `legal_pages_test` — signed out, from the sign-up form: « Confidentialité » and « Lire les conditions » open their bundled text, and back lands on the form |
| « Signaler un problème » (no web counterpart) | `report_problem_test` — from the profile's « Aide et à propos »: a message under 10 characters once trimmed keeps « Envoyer » off; a suggestion goes out (`POST /api/feedback` 204), the sheet closes and the thanks are shown |
| Push activation banner (no web counterpart) | `push_banner_absent_test` — the e2e server cannot push (`channels` without `PUSH`): the inbox shows no activation banner, and never asks for the permission |

## Not covered yet

Tracked in the ledger: passkeys (`MOB-26`, blocked on the e2e stack's plain-HTTP `localhost`), an
expired access token end to end (`MOB-38`), and running this suite in CI (`MOB-37`). What each
scenario above leaves aside is listed under « Non couvert » in its `LEDGER_DONE.md` entry. A test
that closes an open entry moves it to `LEDGER_DONE.md` under the same ID, in the same commit, and
adds a row to « Coverage » above.

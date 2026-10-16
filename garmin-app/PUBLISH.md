# Publishing to the Connect IQ Store

*Garmin information below was gathered on 2026-10-15 from the developer site and the dashboard —
verify the links and the process before relying on it.* Version 1.0.0 submitted for review on
2026-10-15, replaced in review by 1.0.1 on 2026-10-16 (ledger `OPS-35`); each release is tagged
`garmin.X.Y.Z` (skill `garmin-release`).

## Current Situation

- **Developer account**: [apps.garmin.com/developer/dashboard](https://apps.garmin.com/fr-FR/developer/dashboard),
  developer name `pedalons.fr`. Store page:
  [apps.garmin.com/apps/262ea335-a5b7-4a6a-bb30-fc6f5db9b115](https://apps.garmin.com/fr-FR/apps/262ea335-a5b7-4a6a-bb30-fc6f5db9b115)
  (the store's own id, distinct from the manifest's). The "Compte commerçant" (merchant
  account) and the "trial" key/secret under Settings only serve paid apps: not needed.
- **App id**: `d317d3db-6f57-4b75-838f-4cf43a135f79` in `manifest.xml` (set on 2026-09-28). The
  store ties the listing to this UUID: **never change it** once the first version is uploaded.
- **Signing key**: the RSA key in DER format the `Makefile` finds at
  `~/Library/Application Support/Garmin/ConnectIQ/developer_key` (macOS) or
  `~/.Garmin/ConnectIQ/developer_key` (Linux). Every update must be signed with the **same key**:
  a lost key means a new app id, a new listing, and every user reinstalling. It is never committed
  (`.gitignore`); keep a copy outside the workstation.
- **Distribution**: the store only. There is no public upload API, so no CI workflow as for Karoo —
  the `.iq` is built locally and uploaded by hand.

## Listing material: `metadata/`

| File | Field on the store |
|---|---|
| `metadata/app.json` | Name, developer, type, price, website, support and privacy URLs, screenshot order |
| `metadata/description/fr-FR.txt`, `en-US.txt` | Description, one per store language |
| `metadata/version/X.Y.Z/fr-FR.json`, `en-US.json` | `whatsNew`: the release notes of version X.Y.Z |
| `metadata/screenshots/` | Captures, listed in `app.json`'s `screenshots` in display order |
| `metadata/cover.png` | Cover image, 500×500, from `assets/icon-1024.png` |

Write the version folder **before** packaging, as for Karoo. Nothing reads these files
automatically: they are the source the form is filled from, so the listing can be reviewed in a diff.

The description has to stay true to the code (review guideline 4a: every feature, requirement and
dependency stated): a Pédalons account and a team, an Edge paired to a phone through Garmin Connect
for Internet access, the position sent at opening (Positioning permission; the location section of the privacy policy
names the Garmin app). No claim of partnership with Garmin.

**Screenshots** are taken from the simulator (`make simulator`, `make run DEVICE=…`, then the
simulator's screen capture). The current four (2026-10-15) are 246×322, the edge530/edge830
screen, in English: ride list, route list, a downloaded route, the pairing screen. The pairing QR
code is a live code from production: blur it before committing, as was done for Karoo (the six
characters under it may stay, the code expires after ten minutes).

## Release Steps

1. **Version**: bump `version` in `manifest.xml` (`MAJOR.MINOR.PATCH`) and write
   `metadata/version/X.Y.Z/`. The store's "Version de l'application" field (20 characters max) takes
   the same string.
2. **Package**: `make package` builds every device in `DEVICES`, then
   `bin/Pedalons.iq` (signed, with a binary per product of `manifest.xml`). Rebuild it each time:
   a `.iq` left in `bin/` is not proof of anything.
3. **Test on a device** before submitting (guideline 2a: "fully completed, tested"). Either copy
   `bin/Pedalons-<device>.prg` to `GARMIN/Apps/` on the Edge over USB, or upload a **beta**: Garmin
   requires a *different* app id for it (a second UUID in a copy of the manifest), the beta is only
   visible from this developer account, and its store id differs from the real one. Check pairing,
   the ride list, a route download showing up in the Edge's courses, logout.
4. **Upload**: Dashboard → *Charger une application* → the `.iq`, the version, "Application bêta"
   unchecked (sending it accepts the developer licence agreement). Once the file is validated,
   step 2 asks for, as of 2026-10-15:
   - **Title and description per language** (title 50 characters, description and "Nouveautés"
     4000 each): English and Français, from `metadata/`.
   - Hero image (optional, 1440×720, 2 MB max) — none.
   - **Category**: Sports (it offers no sub-category).
   - **User data collected**: yes, with the privacy policy URL — one URL for all languages,
     `/confidentialite`.
   - ANT+ profiles: no. Regional limits: no.
   - **Cover image** 500×500, 300 KB max: `metadata/cover.png`. On-device store icons (128×128):
     no.
   - **Screenshots**, 150 KB max each: add them **one at a time**, the input keeps only the first
     file of a multiple selection.
   - Video (optional): none. **Public contact e-mail**: `contact@pedalons.fr`. Source code URL:
     none.
   - Review notifications: yes. **"Migration de l'application": no** — it is "yes" by default and
     would let the store add new compatible devices on its own, round watches included, which the
     UI is not ready for (ledger `API-111`).
   - Monetisation: no. Companion app and extra hardware: none.

   The first upload showed **"La vérification de la signature a échoué"** next to "Statut :
   vérifiée", with the right key: a store bug acknowledged by Garmin on first uploads with SDK
   9.2.0 (forum report CIQQA-4716). Submitting anyway works, and later versions show the
   signature as verified. On an *update*, the same message means a different key: stop there.
5. **Review**: "within 72 hours" outside holidays (no ANT+ profile, so no extra certification).
   While pending, the app can be previewed and downloaded from the developer account. A rejection
   comes by e-mail with its reasons; fix, bump, upload again.
6. **After approval**: point the site's `/applications` page and the mobile app at the store page
   (today `apps.garmin.description` says "coming soon"), and tell the beta sign-ups
   (`beta-signups`).

## Updates

Same app id, same key, a higher `version`. The upload replaces the binary for every listed product;
products removed from `manifest.xml` stop receiving it. Users get the update through Garmin Connect
or Garmin Express.

## Resources

- [Publishing to the Store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/)
- [App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
- [Beta Apps](https://developer.garmin.com/connect-iq/core-topics/beta-apps/)
- [Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/)

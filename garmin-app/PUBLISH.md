# Publishing to the Connect IQ Store

*Garmin information below was gathered on 2026-10-15 from the developer site and the dashboard —
verify the links and the process before relying on it.* Not published yet (ledger `OPS-35`).

## Current Situation

- **Developer account**: [apps.garmin.com/developer/dashboard](https://apps.garmin.com/fr-FR/developer/dashboard),
  developer name `pedalons.fr`. No app uploaded as of 2026-10-15. The "Compte commerçant" (merchant
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

Write the version folder **before** packaging, as for Karoo. Nothing reads these files
automatically: they are the source the form is filled from, so the listing can be reviewed in a diff.

The description has to stay true to the code (review guideline 4a: every feature, requirement and
dependency stated): a Pédalons account and a team, an Edge paired to a phone through Garmin Connect
for Internet access, the position sent at opening (Positioning permission; the location section of the privacy policy
names the Garmin app). No claim of partnership with Garmin.

**Screenshots** are taken from the simulator (`make simulator`, `make run DEVICE=…`, then the
simulator's screen capture), on one recent large screen (edge1050) and one small one (edge530): the
home menu, a ride with its groups, a route detail, the pairing screen. The pairing QR code is a live
code from production: blur it before committing, as was done for Karoo.

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
   unchecked. Once the file is validated, step 2 of the form asks for the description, screenshots
   and other details: fill them from `metadata/`. Note here which fields the form actually has
   (sizes, limits, languages) at the first upload.
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

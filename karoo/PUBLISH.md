# Publishing to the Karoo Extensions Library

*Hammerhead information below was gathered on 2026-01-24, the release, manifest and self-service
parts re-checked on 2026-10-15 — verify the links and the process before relying on it.*

## Current Situation

Since 2026 Hammerhead has a self-service process ([Extensions: Self-Service for
Developers](https://support.hammerhead.io/hc/en-us/articles/53739708787099)): a developer account on
dashboard.hammerhead.io, the app's **manifest URL** entered in its Extension menu (the app then shows
in the Extension Library of the Karoo devices tied to that account), then a submission to SRAM under
an SDK licence agreement, reviewed over several weeks. Not done yet for Pédalons (ledger `OPS-32`).

## Release, manifest and updates

A release is one tag, `karoo.X.Y.Z`, plus one file written **before** it:
`karoo/metadata/version/X.Y.Z/fr-FR.json`, whose `whatsNew` is the release body on GitHub and the
release notes shown on the Karoo. `.github/workflows/karoo-release.yml` fails without it.

The workflow publishes `pedalons.apk`, `pedalons.png` and `manifest.json` — karoo-ext's
[`KarooAppManifest`](https://github.com/hammerheadnav/karoo-ext/blob/master/lib/src/main/kotlin/io/hammerhead/karooext/models/KarooAppManifest.kt),
built from `karoo/metadata/app.json` (label, description, tags…) plus the version, the notes and
URLs pinned to the tag. Screenshots (480×800, taken on the device) live in
`karoo/metadata/screenshots/`; only those listed in `app.json`'s `screenshots`, in that order, are
published — the first one is what the store listing shows first. Karoo offers an update when the manifest's `latestVersionCode` exceeds the
installed one (`MAJOR*10000 + MINOR*100 + PATCH`, from the tag).

How Karoo finds that manifest — three links, none to be changed lightly:

1. Every APK declares `io.hammerhead.karooext.MANIFEST_URL` =
   `https://www.pedalons.fr/karoo/manifest.json` (`app/src/main/AndroidManifest.xml`). An installed
   APK keeps that URL for good, hence a domain we control rather than a GitHub URL.
2. That URL is a 302, set by traefik labels on the frontend in `docker-compose.yml`, to
   `https://github.com/glandais/pedalons/releases/download/karoo-latest/manifest.json`.
3. `karoo-latest` is a fixed release the workflow rewrites (`gh release upload --clobber`) on each
   tag. Never mark it "Latest" and never delete it. `releases/latest/download/…` is **not** usable
   here: "Latest" is repository-wide, and the first mobile or backend release would take it. The
   in-place rewrite requires GitHub's immutable releases to stay off on the repository.

Moving the manifest elsewhere means changing the redirect only. The Hammerhead dashboard can take the
GitHub URL directly: it is editable there at any time.

## Publishing Steps

### 1. Prepare Your Extension

- Ensure you're using the current [karoo-ext library](https://github.com/hammerheadnav/karoo-ext) (not the deprecated karoo-sdk)
- Configure APK signing for release builds
- Test thoroughly on device

### 2. Publish for Sideloading First

- Push a tag matching `karoo.X.Y.Z` (e.g. `git tag karoo.1.2.3 && git push origin karoo.1.2.3`) —
  `.github/workflows/karoo-release.yml` builds a signed release APK and publishes it as a
  GitHub release automatically; `versionCode`/`versionName` are derived from the tag, and the
  signing keystore comes from the repository's GitHub Actions secrets
- Users can install via the [Hammerhead Companion app](https://support.hammerhead.io/hc/en-us/articles/31576497036827) sideloading feature (Karoo 3) or ADB: long-press the APK link, share it to the Companion, confirm « Install » on the Karoo. Updates are then offered from the app's details page on the Karoo

### 3. Get Community Visibility

- Submit your extension to [awesome-karoo](https://github.com/timklge/awesome-karoo) - a community-maintained list of Karoo extensions
- Many extensions from this list have been added to Hammerhead's official library

### 4. Contact Hammerhead for Official Inclusion

- Join the [Hammerhead Extensions Developers community forum](https://support.hammerhead.io/hc/en-us/community/topics/31298804001435-Hammerhead-Extensions-Developers)
- Reach out to Hammerhead about inclusion in the Native Extension Library
- The [Developer Platform page](https://www.hammerhead.io/pages/developer-platform) suggests partnership is available for both "large brands and developers who are passionate cyclists working on a side project"

## Key Notes

- Hammerhead launched the Extensions Library in March 2025 with only 6 partner apps initially
- The self-service review takes "several weeks"; the approval criteria aren't publicly documented
- Sideloading remains the alternative for apps not in the official library

## Resources

- [Hammerhead Karoo Extensions Library](https://support.hammerhead.io/hc/en-us/articles/34676015530907-Karoo-OS-Extensions-Library)
- [karoo-ext GitHub](https://github.com/hammerheadnav/karoo-ext)
- [karoo-ext-template](https://github.com/hammerheadnav/karoo-ext-template) - Template for new extensions
- [Hammerhead Developer Platform](https://www.hammerhead.io/pages/developer-platform)
- [Hammerhead Extensions Developers Forum](https://support.hammerhead.io/hc/en-us/community/topics/31298804001435-Hammerhead-Extensions-Developers)
- [awesome-karoo community list](https://github.com/timklge/awesome-karoo)

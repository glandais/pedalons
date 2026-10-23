---
name: garmin-release
description: Publish a new version of the Garmin Connect IQ app — pick the next X.Y.Z, bump manifest.xml, write the bilingual whatsNew, package the signed .iq, commit, tag garmin.X.Y.Z, then hand the user the exact store-form values for the manual upload. Use when asked to release, publish, ship or upload the Garmin app.
---

# Garmin release

A release is **a `version` bump in `garmin-app/manifest.xml`**, **two notes files**
(`garmin-app/metadata/version/X.Y.Z/`), **a signed `bin/Pedalons.iq`** and **a tag `garmin.X.Y.Z`**
on the commit the package was built from. There is no store API and no CI workflow: the user uploads
the `.iq` by hand on the Connect IQ dashboard. The process, the store form field by field and the
signing-key rules are in [garmin-app/PUBLISH.md](../../../garmin-app/PUBLISH.md) — read its
« Release Steps » before starting, it is the reference if this skill and it disagree.

Argument (optional): the version, or `patch` / `minor` / `major`. Default: `patch`.

All commands below run from the repo root unless they `cd garmin-app`.

## 1. State of the repo

```bash
git status --short                       # must be clean, on develop
git fetch origin --tags
CUR=$(sed -nE 's/.*<iq:application [^>]*version="([0-9.]+)".*/\1/p' garmin-app/manifest.xml)
LAST=$(git tag --list 'garmin.*' --sort=-v:refname | grep -E '^garmin\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
echo "manifest=$CUR last-tag=$LAST"
git log --oneline "$LAST"..HEAD -- garmin-app   # what the release ships
```

- `LAST` must be `garmin.$CUR`. A mismatch means a version was bumped or uploaded without the
  skill: show both and ask before going further. (Every version has a tag since 1.0.0, tagged
  after the fact on `1b43441e`, the commit that recorded its submission.)
- Nothing under `garmin-app/` since `$LAST` (metadata-only commits aside) → say so and stop.
- Look in those commits for `API-…` items or `backend/` changes the Garmin change relies on
  (`git show --stat <sha>`). The app tolerates an older backend (absent fields read as « unknown »),
  but a feature needing a new endpoint or field stays invisible until the backend is deployed in
  prod. Check it rather than guess: `curl -s https://www.pedalons.fr/api/version` gives the
  deployed `apiVersion` and `commit` (the bare `pedalons.fr` answers nothing), then
  `git merge-base --is-ancestor <backend-sha> <prod-commit>` per backend commit. Tell the user
  which ones are not live yet.
- Ask the user whether the **previous version is approved** on the store. One still in review or
  rejected changes what to do (upload over it, or fix the rejection first): their call.

## 2. Version

Next `MAJOR.MINOR.PATCH` from `$CUR` (`patch` by default; `minor` for a user-visible feature set, at
the user's call). The store's « Version de l'application » field takes the same string (20 characters
max). Never reuse a version the store already received, never move an existing tag.

**Never touch the `id` attribute** of `<iq:application>` (the store listing is bound to it), nor the
products list unless the user asked — products also live in `DEVICES` in the `Makefile`, change both
together, and keep « Migration de l'application » off (ledger `API-111`).

Edit only `version="…"` on the `<iq:application>` line of `garmin-app/manifest.xml`.

## 3. Release notes

Create `garmin-app/metadata/version/X.Y.Z/fr-FR.json` **and** `en-US.json`, same shape as the
previous version's:

```json
{
  "whatsNew": "• Première ligne.\n• Deuxième ligne."
}
```

- Written for a rider reading the store page or Garmin Connect: what changed for them, one `• `
  bullet per change, no commit hashes, ledger IDs or technical terms. A few lines (store limit 4000
  characters).
- French is the reference (lexicon of [docs/BRANDING.md](../../../docs/BRANDING.md)); English says
  the same thing. French quotes `« … »`, English plain quotes `"…"` (escaped `\"` in the JSON);
  check both files parse (`python3 -I -c 'import json,sys;[json.load(open(f)) for f in sys.argv[1:]]' …`).
- Built from the `git log` of step 1; leave out refactors, formatting, docs, build tweaks.
- If the notes already exist (prepared in a feature commit), reread them against the log instead.
- If a change alters what the app needs or does (a new permission in `manifest.xml`, new data sent,
  a new requirement), the store description must say so too (guideline 4a): update
  `garmin-app/metadata/description/*.txt` and flag it to the user.

**Show the version and both texts to the user and wait for their go** before going further.

## 4. Gate and package

```bash
./format.sh garmin-app
cd garmin-app && make clean && make package     # every device of DEVICES, then bin/Pedalons.iq
ls -l bin/Pedalons.iq
```

- `make package` needs the Connect IQ SDK and the developer key; on « Developer key not found »
  **stop** — never run `make keygen` for a release: a new key means a new app id and a new listing
  (PUBLISH.md, « Signing key »).
- Always `make clean` first: a `.iq` left in `bin/` proves nothing.
- The build ends on « N OUT OF N DEVICES BUILT » with N above the 14 products of `DEVICES` (the
  SDK counts device variants): only a count below N, or no « BUILD SUCCESSFUL », is a failure.
  The « Cannot determine if container access is using container type » warnings are known noise.
- Unit tests need the simulator running: `make simulator` returns at once while it is still
  starting, so leave it a few seconds before `make test`. Ask the user whether to run them; if
  they are skipped, say so in the report. Pass = the `PASSED (…)` line.
- Remind the user of the on-device check before upload (guideline 2a): copy
  `bin/Pedalons-<device>.prg` to `GARMIN/Apps/` on their Edge over USB, then pairing, ride list, a
  route download showing up in the courses, logout, plus whatever this release changed. Wait for
  them to confirm, or to say they skip it.

## 5. Commit

```bash
git add garmin-app/manifest.xml garmin-app/metadata
git commit -m "chore(garmin): version X.Y.Z"
```

Straight on `develop`, including whatever `format.sh` changed. Use the session's attribution
trailer. If `OPS-35` or another ledger entry is resolved by this release, move it per the ledger
rules of the root `CLAUDE.md` in the same commit.

## 6. Tag and push — confirm first

Pushing is outward-facing: ask for explicit confirmation right before it.

```bash
git push origin develop
git tag garmin.X.Y.Z                       # lightweight, on the commit just made
git push origin garmin.X.Y.Z
```

The tag marks the source of the uploaded `.iq`; it triggers no workflow.

## 7. Hand over the upload

The upload is the user's (browser, developer licence acceptance). Give them, ready to paste:

- File: the absolute path of `garmin-app/bin/Pedalons.iq`.
- Dashboard: <https://apps.garmin.com/fr-FR/developer/dashboard> → the app → upload a new version
  (not « Charger une application », which creates a new listing). « Application bêta » unchecked.
- « Version de l'application »: `X.Y.Z`.
- « Nouveautés », per language: the `whatsNew` of `fr-FR.json` (Français) and `en-US.json`
  (English), with the `\n` rendered as line breaks.
- The description only if step 3 changed it; every other field of PUBLISH.md step 4 stays as is.
- On an update, **« La vérification de la signature a échoué » means a different key: stop and do
  not submit** (the first-upload store bug only concerned 1.0.0).

Review takes up to 72 hours; a rejection arrives by e-mail — fix, bump to a new patch, release again.

## 8. Report

One short paragraph: version, tag, the notes as they go on the store, whether tests and the device
check ran, any backend change that must be live in prod for the new features to show, and that
users get the update through Garmin Connect / Express once it is approved.

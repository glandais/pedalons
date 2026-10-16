---
name: karoo-release
description: Publish a release of the Karoo extension — pick the next karoo.X.Y.Z, write the bilingual whatsNew, commit, tag, push, follow the GitHub workflow and check the manifest Karoo devices read. Use when asked to release, publish or ship the Karoo app.
---

# Karoo release

A release is **one tag `karoo.X.Y.Z`** plus **two notes files written before it**. Pushing the tag
runs `.github/workflows/karoo-release.yml`, which builds the signed APK, publishes the GitHub
release `karoo.X.Y.Z` and rewrites the fixed `karoo-latest` release (manifest + APK) that every
installed Karoo polls. Background and the three-link manifest chain: [karoo/PUBLISH.md](../../../karoo/PUBLISH.md).

Argument (optional): the version, or `patch` / `minor` / `major`. Default: `patch`.

## 1. State of the repo

```bash
git status --short                       # must be clean, on develop
git fetch origin --tags
LAST=$(git tag --list 'karoo.*' --sort=-v:refname | grep -E '^karoo\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
echo "$LAST"
git log --oneline "$LAST"..HEAD -- karoo   # what the release ships
```

- Nothing under `karoo/` since `$LAST` → say so and stop: there is nothing to release.
- Also look in those commits for `API-…` items or `backend/` changes the Karoo change relies on
  (`git show --stat <sha>`). The app tolerates an older backend (absent fields parse
  as « unknown »), but a feature that needs a new endpoint stays invisible until the backend is
  deployed: tell the user which backend changes must be live in prod.

## 2. Version

Next version from `$LAST` (`patch` by default; `minor` for a user-visible feature set, at the
user's call). `MINOR` and `PATCH` must stay **< 100** — `versionCode = MAJOR*10000 + MINOR*100 +
PATCH` and must strictly increase, or Karoo never offers the update. Never reuse or move an existing
tag.

## 3. Release notes

Create `karoo/metadata/version/X.Y.Z/fr-FR.json` **and** `en-US.json` (the workflow fails without
either), same shape as the previous version's:

```json
{
  "whatsNew": "• Première ligne.\n• Deuxième ligne."
}
```

- Written for a rider reading on the Karoo screen, not for developers: what changed for them, one
  `• ` bullet per change, no commit hashes, ledger IDs or technical terms. Short — a few lines.
- French is the reference (lexicon of [docs/BRANDING.md](../../../docs/BRANDING.md)); English says
  the same thing.
- Built from the `git log` of step 1; leave out pure refactors, formatting, build bumps.
- If the notes already exist (prepared in a feature commit), reread them against the log instead.

**Show the two texts and the version to the user and wait for their go** before going further.

## 4. Gate, commit

```bash
bash karoo/check.sh          # format + assembleDebug; needs gpruser/gprkey in ~/.gradle/gradle.properties
git add karoo/metadata/version/X.Y.Z
git commit -m "chore(karoo): notes de version X.Y.Z"
```

Commit straight on `develop` (no branch); check.sh already ran the formatter — include anything it
changed. Use the commit attribution trailer from the session.

## 5. Tag and push — confirm first

Pushing the tag publishes to every Karoo that has the app installed: **ask for explicit
confirmation** right before it, even if step 3 was approved.

```bash
git push origin develop
git tag karoo.X.Y.Z
git push origin karoo.X.Y.Z
```

Lightweight tag, on the notes commit, pushed after `develop` (the tag must point at a commit already
on the remote branch).

## 6. Follow the workflow

```bash
RUN=$(gh run list --workflow=karoo-release.yml --limit 1 --json databaseId,headBranch \
      --jq '.[] | select(.headBranch=="karoo.X.Y.Z") | .databaseId')
gh run watch "$RUN" --exit-status     # run in background; ~3–5 min
```

On failure: `gh run view "$RUN" --log-failed`, report the error verbatim, and stop. Typical causes:
missing notes file (fails in seconds), expired `GPR_KEY` secret (dependency resolution of
`ktor-client-karoo`), signing secrets. Fixing means a **new patch version** — don't delete and re-push
a tag that has a release.

## 7. Verify what devices see

```bash
gh release view karoo.X.Y.Z --json assets --jq '.assets[].name'
# pedalons.apk, pedalons.png, screenshot-*.png, manifest.json

curl -sL https://www.pedalons.fr/karoo/manifest.json | jq '{latestVersion, latestVersionCode, latestApkUrl, releaseNotes}'
```

`latestVersion` must be `X.Y.Z`, `latestVersionCode` the computed code, `latestApkUrl` pinned to the
`karoo.X.Y.Z` tag. If the pedalons.fr URL still serves the old version, check the GitHub URL directly
(`…/releases/download/karoo-latest/manifest.json`): stale there means the last workflow step failed;
fresh there means caching or the traefik redirect.

Never touch `karoo-latest` by hand: no « Latest » flag, no deletion.

## 8. Report

One short paragraph: version and code, release URL, the notes as published, and any backend change
that has to be deployed for the new features to show up. Updating installed Karoos happens on the
device (app details page in the Extension Library, or Companion sideload).

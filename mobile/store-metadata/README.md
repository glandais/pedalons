# store-metadata

Store-submission declarations that have no home in either store's tooling but must stay under
version control, because getting them wrong means an App Review rejection or a privacy-policy
contradiction.

| File | What it is |
|---|---|
| [`data-safety.md`](data-safety.md) | Source of truth for what the app collects, the iOS privacy manifest contents, the App Store Connect *App Privacy* answers, and the Google Play *Data safety* answers |
| [`app-privacy.json`](app-privacy.json) | App Store Connect *App Privacy*, as `asc web privacy` reads it — §4 of `data-safety.md`, machine-readable |
| [`data-safety.csv`](data-safety.csv) | Google Play *Data safety*, in the Console's own CSV format — §5 of `data-safety.md`, machine-readable |

## Pushing the two forms

Both forms are applied from these files, never typed into the consoles: a hand edit there is
overwritten by the next push, and would not be in git anyway.

```bash
# App Store Connect — needs a web session (2FA): the provider is the ASC team, not the Developer one
asc web auth login --apple-id "gabriel.landais@gmail.com" --provider-id 128752970
asc web privacy plan    --app 6761760079 --file mobile/store-metadata/app-privacy.json --pretty
asc web privacy apply   --app 6761760079 --file mobile/store-metadata/app-privacy.json --allow-deletes --confirm
asc web privacy publish --app 6761760079 --confirm

# Google Play — the Play API service account from android/fastlane/Appfile
cd mobile/android && PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec fastlane data_safety
```

`asc web privacy plan` diffs against what Apple holds, so it doubles as a drift check. Play's
API is **write-only**: to compare, export the form (*Contenu de l'application → Sécurité des
données → Exporter au format CSV*) and diff it against `data-safety.csv`. A Play push then sits in
*Vue d'ensemble de la publication* until someone sends it for review.

Editing the CSV: every row of the Console template is kept, answered or not, because the import
expects the full questionnaire. Start from a fresh export if Google adds questions.

Listing copy and screenshots live elsewhere and are not duplicated here:
`mobile/android/fastlane/metadata/` (Play) and `mobile/metadata/` (App Store, below).

## App Store listing

`mobile/metadata/` holds the App Store copy in `asc`'s canonical layout — `app-info/<locale>.json`
(name, subtitle, privacy URL) and `version/<version>/<locale>.json` (description, keywords, support
and marketing URLs), in `fr-FR` (primary) and `en-US` — plus `review-information.json`, the App Review information
(demo account and the reviewer notes, `notes`), managed by the opt-in `review-information` scope
(asc ≥ 6.0). Never `apply` without reading the plan:

```bash
cd mobile
asc metadata validate --dir ./metadata
asc metadata plan     --app 6761760079 --version 1.1.2 --platform IOS --dir ./metadata --include localizations,review-information --review-dir ../.asc/metadata/review
asc metadata approve  --review-dir ../.asc/metadata/review --all
asc metadata apply    --app 6761760079 --version 1.1.2 --platform IOS --dir ./metadata --include localizations,review-information --review-dir ../.asc/metadata/review --confirm
```

Name, subtitle and keywords form **one indexed pool**: never repeat a word across them, keep keywords
comma-separated without spaces, near 100 characters. The description must only claim what the app
does (guideline 2.3.1) — GPX *import* on mobile, for instance, exists only in the route editor reserved to organizers (`MOB-79`). At the next version, rename the
`version/` folder and add `whatsNew`, which does not exist on a first version.

Set outside `metadata/`, on 24 September 2026: version renamed `1.0` → `1.0.0` (it must match the
build's `CFBundleShortVersionString`), copyright « 2026 Gabriel Landais », manual release, build 53
attached, age rating 4+ (all `NONE` but user-generated content and messaging), third-party content
declared (OpenStreetMap under ODbL, members' content), categories Sports then Health & Fitness, free,
174 territories (mainland China excluded: it requires an ICP filing). Review contact and demo account
(`marketplace-tester@pedalons.fr`) were already in place. `asc validate --app 6761760079 --version
1.0.0 --platform IOS` then reports only the missing screenshots. It checks neither price nor
Mac/Vision Pro distribution — look at *Pricing and Availability* in the browser.

Pitfalls: adding a locale takes **two** `apply` runs (creating the `app-info` localization makes
App Store Connect create the version one, and the version half of the same plan fails with "already
been used" — re-plan and apply again).

`review-information.json` deliberately holds only `demoAccountRequired`, `demoAccountName` and
`notes`: a field left out is not managed, so the contact (name, e-mail, phone) stays out of the
repository and the plan stays empty when nothing changed. Never add `demoAccountPassword` — it cannot
be read back, so every plan would show it as changed, and it must be an `@env:NAME`/`@file:PATH`
reference anyway. `notes` takes no such reference (`@file:` would be pushed literally): the text
lives in the JSON, newlines as `\n`. The review information belongs to **one version** —
App Store Connect copies it, demo account included, when a version is created — so `plan` the new
version right after `asc versions create` to see whether the notes still need an update.
`asc metadata pull --include review-information` rewrites the file from App Store Connect, contact
and a password reference included: trim it back to the three fields before committing.

Version 1.1.0 was created on 14 October 2026 (`asc versions create … --copyright "2026 Gabriel
Landais" --release-type MANUAL`, description and keywords copied from 1.0.0 by App Store Connect),
after 1.0.0 went on sale with build 74.

## Google Play listing

`mobile/android/fastlane/metadata/android/<locale>/` holds the Play copy (`title.txt`,
`short_description.txt` — 80 characters —, `full_description.txt`, the App Store description) and
images. The phone screenshots and the feature graphic are generated, never edited by hand:

```bash
cd mobile
python3 screenshots/seed.py                     # the demo clubs, as for the App Store set
./screenshots/capture-android.sh                # pedalons_e2e emulator -> screenshots/flat/android/
(cd screenshots/koubou && kou generate play.yaml && kou generate feature.yaml)
./screenshots/assemble-play.sh                  # -> metadata/android/<locale>/images/
cd android
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec fastlane listing validate:true   # Google checks, nothing changes
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec fastlane listing                 # then pushes the listing
```

The cards are the App Store ones (same captions, `koubou-strings.xcstrings`) at 1080 x 1920 — Play
refuses a side more than twice the other, which a raw 1080 x 2400 capture is — with a phone drawn in
CSS (`templates/hero-play.html`): Koubou has no Android frame, and a Play listing must not show an
Apple device.

## Rule

`data-safety.md`, `mobile/ios/Runner/PrivacyInfo.xcprivacy`, the two store forms, and
`privacy/privacy-policy.{en,fr}.md` describe the same thing in five places. Change one and
you must change the others in the same commit, or they drift and the drift is invisible until a
reviewer finds it.

`data-safety.md` §8 lists which feature additions force a re-declaration, and the "How to
re-verify" section at its end is a copy-pasteable audit of the code the declarations rest on.

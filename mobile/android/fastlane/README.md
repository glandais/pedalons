fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android test

```sh
[bundle exec] fastlane android test
```

Runs all the tests

### android internal

```sh
[bundle exec] fastlane android internal
```

Upload a new build to Play Store internal track. Run `flutter build appbundle --release` from the project root first.

### android data_safety

```sh
[bundle exec] fastlane android data_safety
```

Push the Data safety form from store-metadata/data-safety.csv (Play Console CSV format). The API is write-only: there is no pull, so the CSV in git is the record, and a hand edit in the Console is overwritten by the next run.

### android listing

```sh
[bundle exec] fastlane android listing
```

Push the store listing alone — titles, descriptions, feature graphic, icon and phone screenshots from metadata/android/ — with no build and no release. The screenshots come from mobile/screenshots/ (capture-android.sh, koubou/play.yaml, assemble-play.sh). Play then holds the change in « Vue d'ensemble de la publication » until it is sent for review. `validate:true` asks Google to check it all without committing anything.

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Deploy a new version to the Google Play production track

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Push a new beta build to TestFlight. Run `flutter build ios --release --no-codesign` from the project root first. Build number comes from pubspec.yaml. Internal testers only, unless `external:true` (publish_beta.sh): the build then also goes to the external group NP (public link), which first passes Apple's beta review, with the version's whatsNew from mobile/metadata/version/<version>/ as « What to Test ».

### ios release

```sh
[bundle exec] fastlane ios release
```

Promote the TestFlight build matching the current pubspec.yaml version to the App Store version in App Store Connect. Run `beta` for that exact version first — this lane does not build or upload a binary. Metadata and screenshots stay untouched (the App Store listing is versioned in mobile/metadata/ and pushed with `asc`, see store-metadata/README.md) and the version is left unsubmitted so you can review it in App Store Connect before submitting for review.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

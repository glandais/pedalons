#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# publish_beta.sh sets PUBLISH_CHANNEL=beta: same build, sent further — the
# external TestFlight group and Play's closed testing track instead of internal
# testers only.
case "${PUBLISH_CHANNEL:-test}" in
  test) IOS_LANE=(beta); ANDROID_LANE=internal ;;
  beta) IOS_LANE=(beta external:true); ANDROID_LANE=closed ;;
  *) echo "PUBLISH_CHANNEL must be test or beta" >&2; exit 1 ;;
esac

./clean.sh

# Use the Homebrew Ruby (which carries the bundler version pinned in the
# fastlane Gemfile.lock) instead of the macOS system Ruby 2.6.
if command -v brew >/dev/null 2>&1; then
  export PATH="$(brew --prefix ruby)/bin:$PATH"
fi

# Each Gemfile.lock pins a bundler version (BUNDLED WITH). A Homebrew Ruby
# upgrade removes that gem's directory while leaving its gemspec behind, so the
# `bundle` shim dies with a LoadError before it even parses a subcommand.
# Reinstall the pinned version when the shim can no longer run. Call this from
# the directory holding the Gemfile.lock.
ensure_bundler() {
  bundle --version >/dev/null 2>&1 && return 0
  local pinned
  pinned=$(awk '/^BUNDLED WITH$/ { getline; gsub(/[[:space:]]/, ""); print; exit }' Gemfile.lock)
  echo ">>> bundler $pinned unusable in $(pwd), reinstalling"
  gem install bundler -v "$pinned"
}

# Get the Ruby side ready first: a missing gem is a five-second failure, and
# there is no reason to discover it after a four-minute build.
(cd ios && ensure_bundler && { bundle check || bundle install; })
(cd android && ensure_bundler && { bundle check || bundle install; })

# Bump build number in pubspec.yaml (the +N suffix). Single source of truth for
# both iOS (CFBundleVersion via $(FLUTTER_BUILD_NUMBER)) and Android (versionCode).
# The bump itself has to happen here — both builds bake the version into the
# artifact — but it is only committed once the two uploads have succeeded, so a
# failed run leaves nothing behind but a dirty pubspec.yaml. The next run bumps
# again from there rather than reusing the number: build numbers are free, and
# TestFlight rejects a duplicate one if the run died *after* the iOS upload.
perl -i -pe 's/^(version:\s*\d+\.\d+\.\d+\+)(\d+)\s*$/$1 . ($2 + 1) . "\n"/e' pubspec.yaml
NEW_VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
echo ">>> Building $NEW_VERSION"

flutter build ios --release --no-codesign
(cd ios && bundle exec fastlane "${IOS_LANE[@]}" --verbose)

export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export PATH="$JAVA_HOME/bin:$PATH"
# Stop the Gradle daemon spawned for this build, even if the upload fails, so it doesn't
# linger holding JDK 21.
trap '(cd android && ./gradlew --quiet --stop)' EXIT
flutter build appbundle --release
(cd android && bundle exec fastlane "$ANDROID_LANE" --verbose)

# Both uploads are through: the build number is now real, so record it.
git add pubspec.yaml
git commit -m "chore(mobile): bump build number to $NEW_VERSION"
git push

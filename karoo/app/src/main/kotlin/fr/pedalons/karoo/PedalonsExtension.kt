package fr.pedalons.karoo

import io.hammerhead.karooext.extension.KarooExtension

/**
 * Pédalons Karoo extension service: what the Karoo lists and updates the app through (its
 * `extension_info`, the manifest URL). It has no data field or effect of its own, the routes are
 * browsed and synced from [MainActivity]. The version it reports is the one of the APK: the release
 * tag in a release build, `1.0.0` locally.
 */
class PedalonsExtension : KarooExtension("pedalons", BuildConfig.VERSION_NAME)

package fr.pedalons.karoo.ui

import android.content.Context
import fr.pedalons.karoo.R

/**
 * How a ride group is named on screen: a name of one or two characters reads « Groupe B » (« A1 »
 * -> « Groupe A1 »), since alone it would not read as a group; any other name is shown as it is («
 * Les Rapides », « Groupe 1 », « Gr. A »). The rule of the app and of the site (KIT §9, decision of
 * 2026-11-12; `mobile/lib/features/rides/domain/group_title.dart`), docs/LEDGER_*.md API-191.
 * [template] carries one `%s`.
 */
internal fun groupTitle(name: String, template: String): String {
    val trimmed = name.trim()
    if (trimmed.isEmpty() || trimmed.codePointCount(0, trimmed.length) > 2) return trimmed
    return template.format(trimmed)
}

internal fun groupLabel(context: Context, name: String): String =
    groupTitle(name, context.getString(R.string.group_title))

package fr.pedalons.karoo.ui

/*
 * Naming a time zone for the « heure de Tokyo » mention of a departure read from elsewhere
 * (docs/LEDGER_*.md API-60, API-191).
 *
 * The zone is named after the city of its IANA id — last segment, `_` -> space — with a small
 * French table. This is the port of `mobile/lib/core/utils/zone_label.dart`, itself the port of
 * `frontend/src/utils/zoneLabel.ts`: the three tables move together, and `ZoneLabelTest` takes the
 * cases of the other two.
 */

// Last IANA segment -> French name, only where French differs from the id.
private val frenchCityNames =
    mapOf(
        // Europe
        "Athens" to "Athènes",
        "Brussels" to "Bruxelles",
        "Bucharest" to "Bucarest",
        "Copenhagen" to "Copenhague",
        "Lisbon" to "Lisbonne",
        "London" to "Londres",
        "Moscow" to "Moscou",
        "Vienna" to "Vienne",
        "Warsaw" to "Varsovie",
        // Africa
        "Algiers" to "Alger",
        "Cairo" to "Le Caire",
        // Americas
        "Mexico_City" to "Mexico",
        "Montreal" to "Montréal",
        "Sao_Paulo" to "São Paulo",
        // Asia
        "Singapore" to "Singapour",
        // Islands
        "Azores" to "Açores",
        "Canary" to "Canaries",
        "Noumea" to "Nouméa",
        "Reunion" to "La Réunion",
    )

// The complement where elision alone would be wrong (plural article, or an id written without it).
private val frenchCityOf =
    mapOf(
        "Azores" to "des Açores",
        "Canary" to "des Canaries",
        "Maldives" to "des Maldives",
    )

// Cities with a mute h: « d'Helsinki ». Any other h is aspirated (« de Hong Kong »).
private val frenchMuteH = setOf("Helsinki", "Honolulu", "Ho Chi Minh")

// `Etc/GMT-9` is UTC+9: POSIX flips the sign. The backend sends these at sea.
private val etcGmt = Regex("""^Etc/GMT([+-])(\d{1,2})$""")
private val utcAliases = setOf("UTC", "Etc/UTC", "Etc/GMT", "Etc/UCT", "Etc/Zulu", "GMT")
private val frenchVowel = Regex("^[AEIOUYÀÂÄÉÈÊËÎÏÔÖÙÛÜŸ]", RegexOption.IGNORE_CASE)

private fun segment(timezone: String): String = timezone.substringAfterLast('/')

/**
 * The city naming [timezone]: `Asia/Tokyo` -> « Tokyo », `America/New_York` -> « New York »,
 * `Europe/London` -> « Londres » in French. `Etc/GMT-9` -> « UTC+9 », `UTC` -> « UTC ».
 */
internal fun zoneCityName(timezone: String, french: Boolean): String {
    if (timezone in utcAliases) return "UTC"
    etcGmt.find(timezone)?.let { match ->
        val hours = match.groupValues[2].toInt()
        if (hours == 0) return "UTC"
        return "UTC${if (match.groupValues[1] == "-") "+" else "-"}$hours"
    }
    val segment = segment(timezone)
    return (if (french) frenchCityNames[segment] else null) ?: segment.replace('_', ' ')
}

/**
 * The complement for « heure {ofCity} »: in French « de Tokyo », « d'Athènes », « du Caire », « des
 * Açores », « de La Réunion », and a bare « UTC » / « UTC+9 »; in any other language the city
 * itself.
 */
internal fun zoneCityOf(timezone: String, french: Boolean): String {
    val city = zoneCityName(timezone, french)
    if (!french) return city
    if (city.startsWith("UTC")) return city
    frenchCityOf[segment(timezone)]?.let {
        return it
    }
    if (city.startsWith("Le ")) return "du ${city.substring(3)}"
    if (city.startsWith("Les ")) return "des ${city.substring(4)}"
    if (frenchVowel.containsMatchIn(city) || city in frenchMuteH) return "d'$city"
    return "de $city"
}

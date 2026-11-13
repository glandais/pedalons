package fr.pedalons.karoo

import android.content.Context
import android.content.res.Configuration
import androidx.test.core.app.ApplicationProvider
import fr.pedalons.karoo.ui.formatDistance
import fr.pedalons.karoo.ui.formatElevation
import fr.pedalons.karoo.ui.formatTimestamp
import java.io.File
import java.time.Instant
import java.util.Locale
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.float
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The cases shared with the app and the site (`contracts/format-cases.json`, see
 * `contracts/format-cases.md`): the same value, in the same language and units, gives the same text
 * on the Karoo (docs/LEDGER_*.md API-191). The app reads the file in
 * `mobile/test/core/utils/format_cases_test.dart`, the site in
 * `frontend/src/utils/formatCases.test.ts`.
 *
 * The Karoo shows distances, elevations and dates only: the other kinds (speed, percent, price…)
 * have no formatter here and are skipped by name — a kind this test does not know fails.
 */
@RunWith(RobolectricTestRunner::class)
class FormatCasesTest {

    private val base: Context = ApplicationProvider.getApplicationContext()

    private fun localized(language: String): Context =
        base.createConfigurationContext(
            Configuration(base.resources.configuration).apply {
                setLocale(Locale.forLanguageTag(language))
            },
        )

    private val notOnTheKaroo =
        setOf("speed", "percent", "grade", "price", "tripSpan", "relative", "memberSince")

    private fun render(case: JsonObject): String? {
        val language = case.getValue("locale").jsonPrimitive.content
        val imperial = case.getValue("units").jsonPrimitive.content == "imperial"
        val input = case.getValue("input")
        val locale = Locale.forLanguageTag(language)
        return when (val kind = case.getValue("kind").jsonPrimitive.content) {
            "distance" -> formatDistance(locale, input.jsonPrimitive.float, imperial)
            "elevation" -> formatElevation(locale, input.jsonPrimitive.float, imperial)
            "shortDateTime" ->
                formatTimestamp(
                    localized(language),
                    Instant.parse(input.jsonObject.getValue("date").jsonPrimitive.content),
                    input.jsonObject.getValue("zone").jsonPrimitive.content,
                    Instant.parse(case.getValue("now").jsonPrimitive.content),
                )
            in notOnTheKaroo -> null
            else ->
                throw IllegalStateException("Unknown kind $kind: add it here or skip it by name")
        }
    }

    @Test
    fun theKarooAgreesWithTheAppAndTheSite() {
        // The working directory of a module's unit tests is the module: karoo/app.
        val cases = Json.parseToJsonElement(File("../../contracts/format-cases.json").readText())
        var checked = 0
        for (element in cases.jsonArray) {
            val case = element.jsonObject
            val actual = render(case) ?: continue
            val expected = case.getValue("expected").jsonPrimitive.content
            // Code point by code point: a plain space where a no-break one is expected must fail.
            assertEquals(
                "${case.getValue("kind")} ${case.getValue("input")} [${case.getValue("locale")}]:" +
                    " « $actual » ≠ « $expected »",
                expected.codePoints().toArray().toList(),
                actual.codePoints().toArray().toList(),
            )
            checked++
        }
        assertTrue("only $checked cases were read", checked >= 12)
    }
}

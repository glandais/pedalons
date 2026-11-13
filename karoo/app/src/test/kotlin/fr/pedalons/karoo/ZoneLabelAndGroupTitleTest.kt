package fr.pedalons.karoo

import fr.pedalons.karoo.ui.groupTitle
import fr.pedalons.karoo.ui.zoneCityName
import fr.pedalons.karoo.ui.zoneCityOf
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Two rules ported from the app (docs/LEDGER_*.md API-191): the city that names a time zone
 * (`mobile/lib/core/utils/zone_label.dart`) and how a ride group is named
 * (`mobile/lib/features/rides/domain/group_title.dart`). The cases are the app's.
 */
class ZoneLabelAndGroupTitleTest {

    @Test
    fun city_isTheLastSegmentOfTheZone() {
        assertEquals("Tokyo", zoneCityName("Asia/Tokyo", french = true))
        assertEquals("New York", zoneCityName("America/New_York", french = false))
        assertEquals("Buenos Aires", zoneCityName("America/Argentina/Buenos_Aires", french = true))
    }

    @Test
    fun city_takesItsFrenchNameInFrenchOnly() {
        assertEquals("Londres", zoneCityName("Europe/London", french = true))
        assertEquals("London", zoneCityName("Europe/London", french = false))
        assertEquals("Le Caire", zoneCityName("Africa/Cairo", french = true))
    }

    @Test
    fun city_ofAZoneAtSeaIsItsOffset() {
        assertEquals("UTC", zoneCityName("UTC", french = true))
        assertEquals("UTC", zoneCityName("Etc/GMT", french = true))
        // POSIX flips the sign.
        assertEquals("UTC+9", zoneCityName("Etc/GMT-9", french = true))
        assertEquals("UTC-3", zoneCityName("Etc/GMT+3", french = false))
        assertEquals("UTC", zoneCityName("Etc/GMT+0", french = true))
    }

    @Test
    fun cityOf_buildsTheFrenchComplement() {
        assertEquals("de Tokyo", zoneCityOf("Asia/Tokyo", french = true))
        assertEquals("d'Athènes", zoneCityOf("Europe/Athens", french = true))
        assertEquals("du Caire", zoneCityOf("Africa/Cairo", french = true))
        assertEquals("des Açores", zoneCityOf("Atlantic/Azores", french = true))
        assertEquals("de La Réunion", zoneCityOf("Indian/Reunion", french = true))
        assertEquals("d'Helsinki", zoneCityOf("Europe/Helsinki", french = true))
        assertEquals("de Hong Kong", zoneCityOf("Asia/Hong_Kong", french = true))
        assertEquals("UTC+9", zoneCityOf("Etc/GMT-9", french = true))
    }

    @Test
    fun cityOf_isTheBareCityOutsideFrench() {
        assertEquals("Athens", zoneCityOf("Europe/Athens", french = false))
    }

    @Test
    fun group_aShortNameIsPrefixed() {
        assertEquals("Groupe B", groupTitle("B", "Groupe %s"))
        assertEquals("Groupe A1", groupTitle("A1", "Groupe %s"))
        assertEquals("Group B", groupTitle(" B ", "Group %s"))
    }

    @Test
    fun group_anyOtherNameIsShownAsItIs() {
        assertEquals("Les Rapides", groupTitle("Les Rapides", "Groupe %s"))
        assertEquals("Groupe 1", groupTitle("Groupe 1", "Groupe %s"))
        assertEquals("Gr. A", groupTitle("Gr. A", "Groupe %s"))
        assertEquals("Fast", groupTitle("Fast", "Group %s"))
        assertEquals("", groupTitle("  ", "Groupe %s"))
    }
}

package fr.pedalons.karoo.auth

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** An access token is usable while it has more than 5 minutes left. */
class TokenExpiryTest {

    private val now = 1_000_000_000L

    private fun usableWithSecondsLeft(seconds: Long) = isUsable(now + seconds * 1000, now)

    @Test fun moreThanFiveMinutesLeft_isUsable() = assertTrue(usableWithSecondsLeft(301))

    @Test fun exactlyFiveMinutesLeft_isNotUsable() = assertFalse(usableWithSecondsLeft(300))

    @Test fun lessThanFiveMinutesLeft_isNotUsable() = assertFalse(usableWithSecondsLeft(299))

    @Test fun expired_isNotUsable() = assertFalse(usableWithSecondsLeft(-1))
}

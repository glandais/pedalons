@file:OptIn(ExperimentalCoroutinesApi::class)

package fr.pedalons.karoo.support

import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestCoroutineScheduler

/** A [Clock] that reads the virtual time of a `runTest`. */
class TestClock(private val scheduler: TestCoroutineScheduler) : Clock() {
    override fun getZone(): ZoneId = ZoneOffset.UTC

    override fun withZone(zone: ZoneId): Clock = this

    override fun instant(): Instant = Instant.ofEpochMilli(scheduler.currentTime)

    override fun millis(): Long = scheduler.currentTime
}

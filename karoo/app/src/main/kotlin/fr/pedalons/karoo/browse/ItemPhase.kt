package fr.pedalons.karoo.browse

import fr.pedalons.karoo.api.RegisteredItem
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.api.STATUS_CANCELLED
import java.time.Duration
import java.time.Instant

/** Where a ride group or a trip stage stands between its departure and its arrival. */
enum class ItemPhase {
    // The departure has not happened.
    UPCOMING,

    // Left, not arrived yet.
    UNDER_WAY,

    // Arrived — or cancelled once its departure is past: it will not happen, so it is never « under
    // way ».
    FINISHED,
}

// The length of an outing when nothing gives it: the server's rule
// (`PublicationEndCalculator.DEFAULT_DURATION`), for a server that sends no arrival.
private val DEFAULT_OUTING_DURATION: Duration = Duration.ofHours(3)

private fun instantOrNull(iso: String?): Instant? =
    if (iso.isNullOrBlank()) null else runCatching { Instant.parse(iso) }.getOrNull()

/**
 * The phase between [start] and [end], two instants of the contract. The rule of the app
 * (`mobile/lib/features/teams/domain/publication_timing.dart`, docs/LEDGER_*.md API-194): without a
 * readable [end], the start plus three hours; a cancelled one is finished from its departure; an
 * unreadable start is upcoming, which hides nothing.
 */
fun itemPhase(start: String?, end: String?, status: String?, now: Instant): ItemPhase {
    val startAt = instantOrNull(start) ?: return ItemPhase.UPCOMING
    val endAt = instantOrNull(end) ?: startAt.plus(DEFAULT_OUTING_DURATION)
    if (startAt.isAfter(now)) return ItemPhase.UPCOMING
    if (status == STATUS_CANCELLED) return ItemPhase.FINISHED
    return if (now.isBefore(endAt)) ItemPhase.UNDER_WAY else ItemPhase.FINISHED
}

fun RegisteredItem.phase(now: Instant): ItemPhase =
    itemPhase(startDateTime, endDateTime, status, now)

/**
 * The one the home screen names: the first registered row that is still to ride — neither cancelled
 * nor finished. Null when there is none.
 */
fun RoutesResponse.nextRegistered(now: Instant): RegisteredItem? =
    registeredItems().firstOrNull { !it.isCancelled && it.phase(now) != ItemPhase.FINISHED }

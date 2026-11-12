package fr.pedalons.repository.common;

import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.enums.Status;
import fr.pedalons.service.team.request.MinRole;
import java.time.Instant;
import java.util.Set;
import lombok.Builder;
import org.jspecify.annotations.Nullable;

/**
 * @param status narrows the listing to a single status. This <b>intersects</b> the visibility rules
 *     applied by {@code TeamEntityRepository.getPedalonsQuery}; it never widens them, so asking for
 *     {@code DRAFT} as a plain member still yields nothing.
 * @param participating keep only the publications the user of {@link #userId()} is registered to.
 *     Yields nothing for an anonymous caller, the same way {@link #minRole()} does.
 * @param ascending order by {@code dateTime} ascending instead of the default descending — what "my
 *     next outing" needs.
 * @param tagIds keep only the publications carrying at least one of these tags (plan D6). Set by
 *     a team's dedicated list only — the rides, the posts or the trips of one team — never by the
 *     mixed feed nor by a cross-team list (plan D7, D13). Null or empty: no filter.
 * @param withoutRoute keep only the rides with no route at all: none on the ride itself, none on any
 *     of its groups. Drops every other type of publication.
 * @param withFullGroup keep only the rides with at least one group at capacity. Drops every other
 *     type of publication.
 * @param notEndedAt keep only the rides and trips not over at this instant — their end, stored or
 *     else {@code dateTime} plus {@code PublicationEndCalculator.DEFAULT_DURATION}, is at or after it
 *     (docs/LEDGER_*.md API-85). Drops every other type of publication.
 * @param endedBefore keep only the rides and trips over at this instant, by the same end. Drops
 *     every other type of publication.
 * @param upcomingFirstAt orders the list in two sections, judged at this instant (docs/LEDGER_*.md
 *     API-185): first the rides and trips {@link #notEndedAt()} would keep, soonest departure
 *     first, then every other row — the ones over and the posts — latest first. Filters nothing,
 *     and wins over {@link #ascending()}.
 * @param dated keep only the rides and trips — the types that have a departure — whatever the other
 *     filters, {@link #upcomingFirstAt()} included: a team's agenda in one call (docs/LEDGER_*.md
 *     API-185). Drops every other type of publication; with a {@link #type()} of another type the
 *     list is empty. False: no such filter.
 */
@Builder(toBuilder = true)
public record PublicationQuery(
    Long domainId,
    @Nullable PublicationType type,
    @Nullable Long userId,
    @Nullable Set<Long> teamIds,
    @Nullable Long pinnedTeamId,
    @Nullable Long id,
    @Nullable String slug,
    @Nullable String search,
    @Nullable Instant from,
    @Nullable Instant to,
    @Nullable Instant notEndedAt,
    @Nullable Instant endedBefore,
    @Nullable Instant upcomingFirstAt,
    @Nullable MinRole minRole,
    @Nullable Status status,
    @Nullable Set<Long> tagIds,
    boolean participating,
    boolean withoutRoute,
    boolean withFullGroup,
    boolean dated,
    boolean ascending,
    int page,
    int size,
    boolean includeDeleted,
    boolean platformAdmin)
    implements TeamEntityQueryInterface {}

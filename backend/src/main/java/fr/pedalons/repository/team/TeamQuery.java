package fr.pedalons.repository.team;

import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamSortBy;
import fr.pedalons.repository.common.PageInterface;
import fr.pedalons.service.team.request.MinRole;
import lombok.Builder;
import org.jspecify.annotations.Nullable;

@Builder
public record TeamQuery(
    int page,
    int size,
    Long domainId,
    @Nullable Long pinnedTeamId,
    @Nullable Long id,
    @Nullable Long userId,
    @Nullable MinRole minRole,
    @Nullable String search,
    /**
     * Restricts to teams that do, or do not, accept a join request from any domain user. Null keeps
     * both. A filter only — it never widens what the visibility rules already allow.
     */
    @Nullable Boolean joinable,
    /** Null keeps the historical order: name ascending. */
    @Nullable TeamSortBy sortBy,
    /** Defaults to DESC when {@code sortBy} is set, as on the other listings. */
    @Nullable SortDirection sortDir,
    /**
     * Lifts the visibility rules for a platform admin's directory of every team of the domain.
     * Never the deleted filter, and never {@code minRole}: "my teams" are real memberships
     * (docs/LEDGER_*.md API-137).
     */
    boolean platformAdmin)
    implements PageInterface {}

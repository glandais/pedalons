package fr.pedalons.service.migration.live;

import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.BiketeamMigrationTargetState;
import fr.pedalons.repository.migration.BiketeamMigrationMapRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.common.SlugService;
import fr.pedalons.service.migration.BiketeamMigrationService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * What a biketeam team would land on in a domain — docs/plans/2026-09-22-biketeam-live-migration.md
 * §7.3. The same rules are evaluated at preview, at confirmation and by the job, since the state can
 * change between the three.
 *
 * <p>Two facts decide, in this order: {@code m}, the team the {@code TEAM} mapping row of {@code
 * teamId} points at, and only when {@code m} is not a live team of the domain, {@code t}, the team at
 * the target slug ({@link #targetSlug}) in the domain, trash included ({@code uk_teams_domain_slug}
 * spans trashed teams). The mapping comes first: a migrated team keeps being that team whatever its
 * slug has become on Pédalons. A team is only ever touched when {@code m} points at it — never a
 * native team.
 *
 * <p>Callers run inside a transaction.
 */
@ApplicationScoped
public class BiketeamTargetResolver {

  /**
   * @param teamId the Pédalons team concerned — the migrated team, the trashed one to set aside, or
   *     the one holding the slug; null when the slug is free and nothing was migrated
   * @param teamName its name, for EXISTING_MIGRATED and SLUG_CONFLICT
   * @param trashed whether it is a trashed team of ours, to set aside before recreating it
   * @param slug the slug the team has or will have: the current one of an EXISTING_MIGRATED team,
   *     otherwise {@link #targetSlug} of the biketeam id
   */
  public record Target(
      BiketeamMigrationTargetState state,
      @Nullable Long teamId,
      @Nullable String teamName,
      boolean trashed,
      String slug) {}

  @Inject BiketeamMigrationMapRepository mapRepo;
  @Inject TeamRepository teamRepository;
  @Inject UserTeamRepository userTeamRepository;

  /**
   * The slug a biketeam team is created at. Biketeam ids ({@code ^[a-z0-9][a-z0-9_.-]{0,254}$})
   * allow {@code _} and {@code .}, and runs of separators, which Pédalons slugs do not: every run of
   * {@code [_.-]} becomes one {@code -}, edge hyphens go, and the result is cut to {@link
   * SlugService#MAX_SLUG_LENGTH}. Two biketeam ids may thus share a slug ({@code club_x}, {@code
   * club.x}): the second one meets a SLUG_CONFLICT. The biketeam id stays the mapping key.
   */
  public static String targetSlug(String biketeamTeamId) {
    String slug = SlugService.slugifyWithinLimit(biketeamTeamId);
    if (slug.isEmpty()) {
      // Unreachable for an id the request token verifier accepted: it starts with [a-z0-9].
      throw new IllegalArgumentException("Biketeam team id without any letter or digit");
    }
    return slug;
  }

  public Target evaluate(Long domainId, String biketeamTeamId) {
    String slug = targetSlug(biketeamTeamId);
    Long mapped = mapRepo.findTriblyId(BiketeamMigrationService.T_TEAM, biketeamTeamId);
    Team mappedTeam = mapped == null ? null : teamRepository.findByIdOptional(mapped).orElse(null);
    boolean mappedHere = mappedTeam != null && mappedTeam.getDomain().getId().equals(domainId);
    if (mappedTeam != null && !mappedTeam.isDeleted()) {
      if (!mappedHere) {
        // The mapping key is global: a database receives a biketeam team in one domain only. A team
        // of another domain that has since been trashed no longer holds it.
        return new Target(
            BiketeamMigrationTargetState.MIGRATED_IN_OTHER_DOMAIN, null, null, false, slug);
      }
      // Wherever its slug went since: renamed on Pédalons, it is still the migrated team.
      return new Target(
          BiketeamMigrationTargetState.EXISTING_MIGRATED,
          mappedTeam.getId(),
          mappedTeam.getName(),
          false,
          mappedTeam.getSlug());
    }
    Optional<Team> atSlug = teamRepository.findBySlugAndDomainIncludingDeleted(domainId, slug);
    if (atSlug.isPresent() && (mappedTeam == null || !atSlug.get().getId().equals(mapped))) {
      Team team = atSlug.get();
      return new Target(
          BiketeamMigrationTargetState.SLUG_CONFLICT, team.getId(), team.getName(), false, slug);
    }
    if (mappedHere) {
      // Trashed on Pédalons — at the slug or elsewhere: set aside, and recreated at the slug.
      return new Target(
          BiketeamMigrationTargetState.NEW, mappedTeam.getId(), mappedTeam.getName(), true, slug);
    }
    return new Target(BiketeamMigrationTargetState.NEW, null, null, false, slug);
  }

  /**
   * Whether {@code user} may migrate into the team again: its ADMIN, or a PLATFORM_ADMIN. A
   * migrated team has had a life on Pédalons since its first migration, and belongs to whoever
   * administers it here.
   */
  public boolean mayAdminister(User user, Long teamId) {
    if (user.isPlatformAdmin()) {
      return true;
    }
    return userTeamRepository
        .findByUserAndTeam(user.getId(), teamId)
        .map(UserTeam::isAdmin)
        .orElse(false);
  }
}

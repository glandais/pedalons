package fr.pedalons.service.user;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.gps.response.GpsServiceConnectionDto;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.users.request.UpdateUserRequest;
import fr.pedalons.dto.users.request.UserPreferencesRequest;
import fr.pedalons.dto.users.response.AccountDeletionImpactDto;
import fr.pedalons.dto.users.response.UserDto;
import fr.pedalons.enums.ThemePreference;
import fr.pedalons.enums.UnitSystem;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.gps.sync.GpsRouteSyncService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.team.TeamService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@ApplicationScoped
public class UserService {

  @Inject UserRepository userRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject GpsServiceConnectionRepository gpsConnectionRepository;

  @Inject AccountErasureService accountErasureService;

  @Inject UserTeamRepository userTeamRepository;

  @Inject GpsRouteSyncService gpsRouteSyncService;

  @Inject TeamService teamService;

  @Logged
  public UserDto getUserDto() {
    return toDto(pedalonsContext.getUser());
  }

  /**
   * The member's own profile, connected GPS services included. Every endpoint that answers with a
   * {@link UserDto} goes through here: the clients replace their whole user with it (the SSR seeds
   * {@code /me} with the refresh's answer), so a profile without its services would show them
   * disconnected and send the member to connect them again.
   */
  public UserDto toDto(User user) {
    // Their route sync state in one query for all of them (docs/LEDGER_*.md API-120).
    List<GpsServiceConnectionDto> connections =
        gpsRouteSyncService.toDtos(
            user.getDomain().getId(), gpsConnectionRepository.findByUser(user.getId()));
    return UserDto.from(user, connections);
  }

  @Logged
  @Transactional
  public UserDto updateUser(UpdateUserRequest request) {
    User user = pedalonsContext.getUser();

    String displayName = request.displayName();
    if (displayName != null) {
      user.setDisplayName(displayName);
    }

    UnitSystem unitSystem = request.unitSystem();
    if (unitSystem != null) {
      user.setUnitSystem(unitSystem);
    }

    userRepository.persist(user);
    return toDto(user);
  }

  /**
   * Writes the display preferences the profile screen owns, leaving the rest of the profile alone.
   *
   * <p>A null field means "unchanged", not "clear": see {@link UserPreferencesRequest}.
   */
  @Logged
  @Transactional
  public UserDto updatePreferences(UserPreferencesRequest request) {
    User user = pedalonsContext.getUser();

    UnitSystem unitSystem = request.unitSystem();
    if (unitSystem != null) {
      user.setUnitSystem(unitSystem);
    }
    ThemePreference theme = request.theme();
    if (theme != null) {
      user.setTheme(theme);
    }
    String language = request.language();
    if (language != null) {
      user.setLanguage(language);
    }
    String timezone = request.timezone();
    if (timezone != null) {
      try {
        ZoneId.of(timezone);
      } catch (DateTimeException e) {
        throw new BadRequestException(ErrorCode.INVALID_TIMEZONE, e);
      }
      user.setTimezone(timezone);
    }
    Boolean contactable = request.contactableByMembers();
    if (contactable != null) {
      user.setContactableByMembers(contactable);
    }

    userRepository.persist(user);
    return toDto(user);
  }

  /** What {@link #deleteUser} would do to the current user's teams, for the confirmation. */
  @Logged
  @Transactional
  public AccountDeletionImpactDto getDeletionImpact() {
    User user = pedalonsContext.getUser();
    Long domainId = pedalonsContext.getDomainId();
    // Three queries whatever the number of teams. A migrated team is named once, in its own list:
    // what the member must do about it is not what they do about the others.
    List<Team> migrated =
        userTeamRepository.findMigratedTeamsAdministeredAlone(user.getId(), domainId);
    Set<Long> migratedIds = migrated.stream().map(Team::getId).collect(Collectors.toSet());
    List<TeamPublicationDto> blockingTeams =
        userTeamRepository.findTeamsLeftWithoutAdmin(user.getId(), domainId).stream()
            .filter(team -> !migratedIds.contains(team.getId()))
            .map(TeamPublicationDto::from)
            .toList();
    List<TeamPublicationDto> deletedTeams =
        userTeamRepository.findTeamsAdministeredAlone(user.getId(), domainId).stream()
            .filter(team -> !migratedIds.contains(team.getId()))
            .map(TeamPublicationDto::from)
            .toList();
    List<TeamPublicationDto> migratedTeams =
        migrated.stream().map(TeamPublicationDto::from).toList();
    return new AccountDeletionImpactDto(
        !blockingTeams.isEmpty() || !migratedTeams.isEmpty(),
        blockingTeams,
        deletedTeams,
        migratedTeams);
  }

  /**
   * Deletes the current account. Three steps, so that no transaction stays open while a GPS service
   * is called (docs/LEDGER_*.md API-120): the refusals are checked first, in their own transaction,
   * so that nothing is removed from a service for an account whose deletion is then refused; the
   * routes the automatic sync placed at the member's services are removed next, with no
   * transaction open and within a bounded time; the deletion itself runs last, in one transaction,
   * the refusals checked again.
   */
  @Logged
  public void deleteUser() {
    Long userId = pedalonsContext.getUser().getId();
    Long domainId = pedalonsContext.getDomainId();
    QuarkusTransaction.requiringNew().run(() -> checkDeletable(userId, domainId));
    accountErasureService.removeSyncedRoutes(userId);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              checkDeletable(userId, domainId);
              // A team they administer alone would be left with no member at all: it goes with the
              // account, through the same deletion as DELETE /teams/{slug}. The confirmation named
              // these teams (GET /users/me/deletion-impact).
              for (Team team : userTeamRepository.findTeamsAdministeredAlone(userId, domainId)) {
                teamService.delete(team);
              }
              // Erased now, not flagged for later: nothing ever came back for a flagged account,
              // and the policy, the app and the store listings all promise the data is gone.
              accountErasureService.erase(userRepository.findById(userId));
            });
    // The request context memoizes the active user; it is no longer active.
    pedalonsContext.invalidateUser();
  }

  private void checkDeletable(Long userId, Long domainId) {
    // A team that came from biketeam is where biketeam redirects its old addresses: the erasure
    // must not trash it, even with no other member (it would, below). Checked first, since what
    // the member must do differs: name another admin, or — a platform admin — cancel the
    // switch-over on biketeam before deleting the team.
    if (!userTeamRepository.findMigratedTeamsAdministeredAlone(userId, domainId).isEmpty()) {
      throw new BusinessException(ErrorCode.SOLE_MIGRATED_TEAM_ADMIN);
    }
    // The erasure drops every membership and promotes nobody: the last admin of a team others
    // still belong to would leave them a team no one can run. They name another admin, or delete
    // the team, first — the same rule as leaving the team (LAST_ADMIN).
    if (!userTeamRepository.findTeamsLeftWithoutAdmin(userId, domainId).isEmpty()) {
      throw new BusinessException(ErrorCode.SOLE_TEAM_ADMIN);
    }
  }
}

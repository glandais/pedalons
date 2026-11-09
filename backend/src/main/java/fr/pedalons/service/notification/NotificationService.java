package fr.pedalons.service.notification;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.notification.NotificationPreference;
import fr.pedalons.domain.notification.NotificationSettings;
import fr.pedalons.domain.notification.NotificationTeamMute;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.notifications.request.NotificationPreferenceUpdate;
import fr.pedalons.dto.notifications.request.NotificationPreferencesRequest;
import fr.pedalons.dto.notifications.request.NotificationTeamPreferenceUpdate;
import fr.pedalons.dto.notifications.response.NotificationDto;
import fr.pedalons.dto.notifications.response.NotificationListResponse;
import fr.pedalons.dto.notifications.response.NotificationPreferenceDto;
import fr.pedalons.dto.notifications.response.NotificationPreferencesDto;
import fr.pedalons.dto.notifications.response.NotificationTeamPreferenceDto;
import fr.pedalons.dto.notifications.response.UnreadCountDto;
import fr.pedalons.dto.users.response.ProfileNotificationSummaryDto;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.notification.NotificationDeliveryRepository;
import fr.pedalons.repository.notification.NotificationPreferenceRepository;
import fr.pedalons.repository.notification.NotificationRepository;
import fr.pedalons.repository.notification.NotificationSettingsRepository;
import fr.pedalons.repository.notification.NotificationTeamMuteRepository;
import fr.pedalons.repository.notification.PushDeviceRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * The current user's inbox and preferences. Everything is scoped to the caller and their domain:
 * someone else's notification is a 404, never a 403.
 */
@ApplicationScoped
public class NotificationService {

  @Inject NotificationRepository notificationRepository;
  @Inject NotificationPreferenceRepository preferenceRepository;
  @Inject NotificationDeliveryRepository deliveryRepository;
  @Inject PushDeviceRepository pushDeviceRepository;
  @Inject NotificationTeamMuteRepository teamMuteRepository;
  @Inject NotificationSettingsRepository settingsRepository;
  @Inject UserTeamRepository userTeamRepository;
  @Inject NotificationChannels channels;
  @Inject PedalonsQueryContext pedalonsContext;

  @Logged
  @Transactional
  public NotificationListResponse list(int page, int size, boolean unreadOnly) {
    Long userId = pedalonsContext.getUserId();
    Long domainId = pedalonsContext.getDomainId();
    int pageSize =
        size <= 0 ? BaseRepository.DEFAULT_PAGE_SIZE : Math.min(size, BaseRepository.MAX_PAGE_SIZE);
    int pageNumber = Math.max(page, 0);
    List<NotificationDto> items =
        notificationRepository.page(userId, domainId, unreadOnly, pageNumber, pageSize).stream()
            .map(NotificationDto::from)
            .toList();
    long unread = notificationRepository.count(userId, domainId, true);
    long total = unreadOnly ? unread : notificationRepository.count(userId, domainId, false);
    return new NotificationListResponse(items, total, unread, pageNumber, pageSize);
  }

  @Logged
  @Transactional
  public UnreadCountDto unreadCount() {
    return new UnreadCountDto(
        notificationRepository.count(
            pedalonsContext.getUserId(), pedalonsContext.getDomainId(), true));
  }

  @Logged
  @Transactional
  public void markRead(String notificationId) {
    boolean found =
        notificationRepository.markRead(
            TsidUtils.toLong(notificationId),
            pedalonsContext.getUserId(),
            pedalonsContext.getDomainId(),
            Instant.now());
    if (!found) {
      throw new NotFoundException();
    }
  }

  @Logged
  @Transactional
  public void markAllRead() {
    notificationRepository.markAllRead(
        pedalonsContext.getUserId(), pedalonsContext.getDomainId(), Instant.now());
  }

  @Logged
  @Transactional
  public NotificationPreferencesDto getPreferences() {
    return preferences(pedalonsContext.getUserId(), pedalonsContext.getDomainId());
  }

  /**
   * Writes the cells sent, leaves the others alone. A cell set back to its default is stored like
   * any other: the row records a choice, and a later change of default should not override it.
   */
  @Logged
  @Transactional
  public NotificationPreferencesDto updatePreferences(NotificationPreferencesRequest request) {
    User user = pedalonsContext.getUser();
    Map<Cell, NotificationPreference> existing = new HashMap<>();
    for (NotificationPreference preference : preferenceRepository.findByUser(user.getId())) {
      existing.put(new Cell(preference.getType(), preference.getChannel()), preference);
    }
    for (NotificationPreferenceUpdate update : request.preferences()) {
      if (!update.channel().isConfigurable()) {
        throw new BadRequestException();
      }
      NotificationPreference preference = existing.get(new Cell(update.type(), update.channel()));
      if (preference == null) {
        preference =
            new NotificationPreference(user, update.type(), update.channel(), update.enabled());
        preferenceRepository.persist(preference);
        existing.put(new Cell(update.type(), update.channel()), preference);
      } else {
        preference.setEnabled(update.enabled());
      }
    }
    if (request.teams() != null) {
      Map<String, Team> teams = memberships(user.getId(), pedalonsContext.getDomainId());
      for (NotificationTeamPreferenceUpdate update : request.teams()) {
        Team team = teams.get(update.teamSlug());
        if (team == null) {
          // Not one of the caller's teams on this site — the same answer as a team that does not
          // exist, so the endpoint says nothing about other teams.
          throw new NotFoundException();
        }
        Optional<NotificationTeamMute> mute =
            teamMuteRepository.findByUserAndTeam(user.getId(), team.getId());
        if (update.muted() && mute.isEmpty()) {
          teamMuteRepository.persist(new NotificationTeamMute(user, team));
        } else if (!update.muted()) {
          mute.ifPresent(teamMuteRepository::delete);
        }
      }
    }
    if (request.emailDigest() != null) {
      NotificationSettings settings =
          settingsRepository
              .findByUser(user.getId())
              .orElseGet(() -> {
                NotificationSettings created = new NotificationSettings(user);
                settingsRepository.persist(created);
                return created;
              });
      settings.setEmailDigest(request.emailDigest());
    }
    return preferences(user.getId(), pedalonsContext.getDomainId());
  }

  /**
   * The profile overview's notification line: what {@link #getPreferences()} would show, reduced to
   * the channels the user receives anything on. Two queries, whatever the number of types.
   */
  public ProfileNotificationSummaryDto summary(Long userId) {
    Set<NotificationChannel> available = channels.available();
    List<NotificationChannel> shown =
        Arrays.stream(NotificationChannel.values()).filter(available::contains).toList();
    Map<Cell, Boolean> overrides = new HashMap<>();
    if (!shown.isEmpty()) {
      for (NotificationPreference preference : preferenceRepository.findByUser(userId)) {
        overrides.put(
            new Cell(preference.getType(), preference.getChannel()), preference.isEnabled());
      }
    }
    List<NotificationChannel> enabled =
        shown.stream()
            .filter(channel ->
                Arrays.stream(NotificationType.values())
                    .anyMatch(type ->
                        overrides.getOrDefault(
                            new Cell(type, channel), type.isEnabledByDefault(channel))))
            .toList();
    boolean digest =
        available.contains(NotificationChannel.EMAIL)
            && settingsRepository
                .findByUser(userId)
                .map(NotificationSettings::isEmailDigest)
                .orElse(false);
    return new ProfileNotificationSummaryDto(shown, enabled, digest);
  }

  /** The caller's live teams on this domain, by slug, in name order. */
  private Map<String, Team> memberships(Long userId, Long domainId) {
    return userTeamRepository.findByUserId(userId).stream()
        .map(UserTeam::getTeam)
        .filter(team -> team.getDomain().getId().equals(domainId))
        .sorted(Comparator.comparing(Team::getName, String.CASE_INSENSITIVE_ORDER))
        .collect(Collectors.toMap(Team::getSlug, team -> team, (a, b) -> a, LinkedHashMap::new));
  }

  private record Cell(NotificationType type, NotificationChannel channel) {}

  private NotificationPreferencesDto preferences(Long userId, Long domainId) {
    Map<Cell, Boolean> overrides = new HashMap<>();
    for (NotificationPreference preference : preferenceRepository.findByUser(userId)) {
      overrides.put(
          new Cell(preference.getType(), preference.getChannel()), preference.isEnabled());
    }
    Set<NotificationChannel> available = channels.available();
    List<NotificationChannel> shown =
        Arrays.stream(NotificationChannel.values()).filter(available::contains).toList();
    List<NotificationPreferenceDto> cells = new ArrayList<>();
    for (NotificationType type : NotificationType.values()) {
      for (NotificationChannel channel : shown) {
        boolean byDefault = type.isEnabledByDefault(channel);
        cells.add(
            new NotificationPreferenceDto(
                type,
                channel,
                overrides.getOrDefault(new Cell(type, channel), byDefault),
                byDefault));
      }
    }
    Set<Long> muted =
        teamMuteRepository.findByUser(userId).stream()
            .map(mute -> mute.getTeam().getId())
            .collect(Collectors.toSet());
    List<NotificationTeamPreferenceDto> teams =
        memberships(userId, domainId).values().stream()
            .map(team ->
                new NotificationTeamPreferenceDto(
                    team.getSlug(), team.getName(), muted.contains(team.getId())))
            .toList();
    boolean digest =
        settingsRepository
            .findByUser(userId)
            .map(NotificationSettings::isEmailDigest)
            .orElse(false);
    return new NotificationPreferencesDto(shown, cells, teams, digest);
  }

  /**
   * Forgets what the pipeline holds about a user whose account is being deleted: their inbox with
   * its pending deliveries, their preferences, team mutes and settings, and their push devices.
   *
   * <p>The account itself is only flagged deleted, so the {@code on delete cascade} of the
   * migration never fires. Nothing more would be sent anyway — the fan-out and the senders both skip
   * deleted accounts — but a push token is a device identifier held for a purpose that no longer
   * exists, and an inbox nobody can open again is data kept for nothing. Children first: the test
   * schema is generated by Hibernate, which knows nothing of the cascade.
   *
   * <p>The events stay: they belong to everyone they fanned out to, and the retention window
   * removes them — along with the actor name they snapshot — within {@code retention-days}.
   */
  @Transactional(Transactional.TxType.MANDATORY)
  public void forgetUser(Long userId) {
    deliveryRepository.deleteByRecipient(userId);
    notificationRepository.deleteByRecipient(userId);
    preferenceRepository.deleteByUser(userId);
    teamMuteRepository.deleteByUser(userId);
    settingsRepository.deleteByUser(userId);
    pushDeviceRepository.deleteByUser(userId);
  }
}

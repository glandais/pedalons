package fr.pedalons.service.user;

import fr.pedalons.dto.publications.response.PublicationListResponse;
import fr.pedalons.dto.users.response.ProfileParticipationSummaryDto;
import fr.pedalons.dto.users.response.ProfileSummaryDto;
import fr.pedalons.dto.users.response.ProfileTeamDto;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.repository.auth.PasskeyRepository;
import fr.pedalons.repository.moderation.UserBlockRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.common.PublicationService;
import fr.pedalons.service.device.PairedDeviceService;
import fr.pedalons.service.notification.NotificationService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.List;

/**
 * The profile overview's state lines, one request for all of them (profile navigation redesign,
 * 2026-10). Each part is a count or a short list read in a fixed number of queries — the next
 * outing goes through the ordinary participation list, whose lookups resolve per page — so the
 * cost does not grow with the user's teams, blocks, devices or registrations ({@code
 * ProfileSummaryQueryCountTest}).
 *
 * <p>Everything is scoped to the caller: a user belongs to one domain, and the teams are filtered by
 * the current one like every other team query.
 */
@ApplicationScoped
public class ProfileSummaryService {

  @Inject PedalonsQueryContext pedalonsContext;
  @Inject PublicationService publicationService;
  @Inject UserTeamRepository userTeamRepository;
  @Inject PasskeyRepository passkeyRepository;
  @Inject UserBlockRepository userBlockRepository;
  @Inject PairedDeviceService pairedDeviceService;
  @Inject NotificationService notificationService;

  @Logged
  @Transactional
  public ProfileSummaryDto getSummary() {
    Long userId = pedalonsContext.getUserId();
    Long domainId = pedalonsContext.getDomainId();
    Instant now = Instant.now();

    // The upcoming page of one row is both the next outing and, through its total, the count.
    PublicationListResponse upcoming =
        publicationService.listMyParticipations(now, null, null, ListViewMode.COMPACT, 0, 1);
    long pastCount = publicationService.countMyParticipations(null, now);
    ProfileParticipationSummaryDto participations =
        new ProfileParticipationSummaryDto(upcoming.total(), pastCount, upcoming.publications());

    List<ProfileTeamDto> teams =
        userTeamRepository.findByUserAndDomainWithTeam(userId, domainId).stream()
            .map(membership ->
                new ProfileTeamDto(
                    membership.getTeam().getSlug(),
                    membership.getTeam().getName(),
                    membership.getRole()))
            .toList();

    return new ProfileSummaryDto(
        participations,
        teams,
        passkeyRepository.countByUserId(userId),
        pairedDeviceService.listPairedDevices(),
        userBlockRepository.countByBlocker(userId),
        notificationService.summary(userId));
  }
}

package fr.pedalons.service.notification;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.notification.TeamWebhook;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.teams.request.TeamWebhookRequest;
import fr.pedalons.dto.teams.response.TeamWebhookDto;
import fr.pedalons.dto.teams.response.TeamWebhookTestDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.TeamWebhookKind;
import fr.pedalons.infrastructure.webhook.WebhookHttpClient;
import fr.pedalons.repository.notification.TeamWebhookDeliveryRepository;
import fr.pedalons.repository.notification.TeamWebhookRepository;
import fr.pedalons.repository.platform.DomainAliasRepository;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.team.TeamService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.net.URI;
import org.jspecify.annotations.Nullable;

/**
 * A team's outgoing webhook, as its administrators configure it — the same right as editing the
 * team's settings.
 */
@ApplicationScoped
public class TeamWebhookService {

  /** Characters of the URL shown at its end: enough to tell two apart, not enough to use one. */
  private static final int VISIBLE_TAIL = 4;

  @Inject TeamWebhookRepository webhookRepository;
  @Inject TeamWebhookDeliveryRepository deliveryRepository;
  @Inject TeamWebhookDeliveryService deliveryService;
  @Inject TeamWebhookMessages messages;
  @Inject TeamService teamService;
  @Inject DomainAliasRepository domainAliasRepository;

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public TeamWebhookDto get(String teamSlug) {
    Team team = teamService.getTeam(teamSlug);
    return webhookRepository
        .findByTeam(team.getId())
        .map(TeamWebhookService::toDto)
        .orElse(TeamWebhookDto.none());
  }

  /** Creates or changes the webhook. A request without URL keeps the one in place. */
  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public TeamWebhookDto save(String teamSlug, TeamWebhookRequest request) {
    Team team = teamService.getTeam(teamSlug);
    TeamWebhook webhook = webhookRepository.findByTeam(team.getId()).orElse(null);
    String url = request.url() == null || request.url().isBlank() ? null : request.url().strip();
    if (url != null) {
      URI parsed = TeamWebhookDeliveryService.parse(url);
      if (parsed == null || !WebhookHttpClient.isAcceptable(parsed)) {
        throw new BadRequestException(ErrorCode.WEBHOOK_URL_INVALID);
      }
    } else if (webhook == null) {
      throw new BadRequestException(ErrorCode.WEBHOOK_URL_INVALID);
    }
    if (webhook == null) {
      webhook = new TeamWebhook(team, url, request.language(), request.enabled());
      webhookRepository.persist(webhook);
    } else {
      if (url != null && !url.equals(webhook.getUrl())) {
        webhook.setUrl(url);
        // A new endpoint starts with a clean slate: the last error was the old one's.
        webhook.setLastStatus(null);
        webhook.setLastError(null);
        webhook.setLastAttemptAt(null);
      }
      webhook.setLanguage(request.language());
      webhook.setEnabled(request.enabled());
    }
    return toDto(webhook);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public void delete(String teamSlug) {
    Team team = teamService.getTeam(teamSlug);
    webhookRepository
        .findByTeam(team.getId())
        .ifPresent(webhook -> {
          // Explicitly, rather than by the migration's cascade: the test schema has none.
          deliveryRepository.delete("webhook.id", webhook.getId());
          webhookRepository.delete(webhook);
        });
  }

  /**
   * Posts a test message now and says how the endpoint answered. Not transactional: the post is
   * made with no connection held, and the outcome is not recorded — it is shown, not queued.
   */
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public TeamWebhookTestDto test(String teamSlug) {
    record Target(URI url, String language, String teamName, String siteName) {}
    Target target =
        QuarkusTransaction.requiringNew()
            .call(() -> {
              Team team = teamService.getTeam(teamSlug);
              TeamWebhook webhook =
                  webhookRepository
                      .findByTeam(team.getId())
                      .orElseThrow(() -> new BadRequestException(ErrorCode.WEBHOOK_URL_INVALID));
              URI url = TeamWebhookDeliveryService.parse(webhook.getUrl());
              if (url == null) {
                throw new BadRequestException(ErrorCode.WEBHOOK_URL_INVALID);
              }
              String siteName =
                  domainAliasRepository
                      .findActiveByPinnedTeam(team.getId())
                      .map(alias -> alias.getName())
                      .orElse(team.getDomain().getName());
              return new Target(url, webhook.getLanguage(), team.getName(), siteName);
            });
    TeamWebhookDeliveryService.Outcome outcome =
        deliveryService.post(
            target.url(),
            messages.test(target.url(), target.language(), target.teamName(), target.siteName()));
    return new TeamWebhookTestDto(outcome.success(), outcome.statusCode(), outcome.error());
  }

  private static TeamWebhookDto toDto(TeamWebhook webhook) {
    URI url = TeamWebhookDeliveryService.parse(webhook.getUrl());
    return new TeamWebhookDto(
        true,
        mask(webhook.getUrl(), url),
        url == null ? null : TeamWebhookKind.of(url),
        webhook.getLanguage(),
        webhook.isEnabled(),
        webhook.getLastStatus(),
        webhook.getLastError(),
        webhook.getLastAttemptAt());
  }

  /** {@code https://hooks.slack.com/…XXXX}: which service, and which of two URLs — nothing usable. */
  static String mask(String raw, @Nullable URI url) {
    String tail = raw.length() > VISIBLE_TAIL ? raw.substring(raw.length() - VISIBLE_TAIL) : "";
    String head =
        url != null && url.getHost() != null ? url.getScheme() + "://" + url.getHost() : "";
    return head + "/…" + tail;
  }
}

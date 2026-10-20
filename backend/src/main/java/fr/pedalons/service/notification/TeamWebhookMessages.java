package fr.pedalons.service.notification;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.TeamWebhookKind;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.net.URI;
import java.util.Objects;
import org.jspecify.annotations.Nullable;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/**
 * What a team webhook receives, in the shape its URL calls for — see {@link TeamWebhookKind}. Texts
 * are the same as the e-mail's and the push's, in the webhook's language.
 */
@ApplicationScoped
public class TeamWebhookMessages {

  /** Discord refuses a longer {@code content}. */
  private static final int DISCORD_MAX = 2000;

  @Inject NotificationTexts texts;
  @Inject ObjectMapper objectMapper;

  /**
   * The event, as the snapshot the fan-out froze on it. Expects a fanned-out event.
   *
   * <p>Its date reads in the subject's own zone, named when it is not the team's — the webhook's
   * audience is the team, and nobody's « chez vous » applies (docs/LEDGER_*.md API-60).
   * {@code teamTimezone} also dates a row fanned out before the subject's zone was frozen.
   */
  public String forEvent(
      NotificationEventEntry event, URI url, String language, @Nullable String teamTimezone) {
    NotificationTexts.Zones zones =
        NotificationTexts.Zones.forTeam(event.getSubjectTimezone(), teamTimezone);
    String teamName = Objects.requireNonNull(event.getTeamName());
    String subjectName = Objects.requireNonNull(event.getSubjectName());
    NotificationTexts.Rendered rendered =
        texts.render(
            event.getType(),
            language,
            zones,
            event.getActorName(),
            teamName,
            subjectName,
            event.getSubjectDateTime(),
            event.getExcerpt(),
            Objects.requireNonNull(event.getSiteName()),
            event.changeList());
    String link =
        event.getBaseUrl()
            + NotificationLinks.subjectPath(
                Objects.requireNonNull(event.getSubjectType()),
                Objects.requireNonNull(event.getTeamSlug()),
                Objects.requireNonNull(event.getSubjectSlug()));
    return switch (TeamWebhookKind.of(url)) {
      case SLACK -> slack(rendered.title(), rendered.body(), link, rendered.cta());
      case MATTERMOST -> mattermost(rendered.title(), rendered.body(), link, rendered.cta());
      case DISCORD -> discord(rendered.title(), rendered.body(), link);
      case GENERIC -> {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("type", event.getType().name());
        root.put("eventId", TsidUtils.toString(event.getId()));
        root.put("createdAt", event.getCreatedAt().toString());
        ObjectNode team = root.putObject("team");
        team.put("slug", event.getTeamSlug());
        team.put("name", teamName);
        ObjectNode subject = root.putObject("subject");
        subject.put("type", Objects.requireNonNull(event.getSubjectType()).name());
        subject.put("slug", event.getSubjectSlug());
        subject.put("name", subjectName);
        subject.put(
            "dateTime",
            event.getSubjectDateTime() == null ? null : event.getSubjectDateTime().toString());
        subject.put(
            "timezone", event.getSubjectDateTime() == null ? null : zones.subject().getId());
        subject.put("url", link);
        root.put("actorName", event.getActorName());
        ArrayNode changes = root.putArray("changes");
        for (NotificationChange change : event.changeList()) {
          changes.add(change.name());
        }
        root.put("title", rendered.title());
        root.put("text", rendered.body());
        yield write(root);
      }
    };
  }

  /** The message "Test" sends, so an administrator can see the channel is wired. */
  public String test(URI url, String language, String teamName, String siteName) {
    String title = texts.webhookTestText(language, "title", teamName, siteName);
    String body = texts.webhookTestText(language, "body", teamName, siteName);
    return switch (TeamWebhookKind.of(url)) {
      case SLACK -> slack(title, body, null, null);
      case MATTERMOST -> mattermost(title, body, null, null);
      case DISCORD -> discord(title, body, null);
      case GENERIC -> {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("type", "TEST");
        root.put("title", title);
        root.put("text", body);
        yield write(root);
      }
    };
  }

  private String slack(String title, String body, @Nullable String link, @Nullable String cta) {
    StringBuilder text = new StringBuilder("*").append(slackEscape(title)).append("*\n");
    text.append(slackEscape(body));
    if (link != null && cta != null) {
      text.append("\n<").append(link).append('|').append(slackEscape(cta)).append('>');
    }
    ObjectNode root = objectMapper.createObjectNode();
    root.put("text", text.toString());
    return write(root);
  }

  /**
   * Slack's payload, as Mattermost's compatibility layer reads it: {@code <url|label>} links work,
   * but a single asterisk is italics there, and {@code @channel}, {@code @here} and {@code @all}
   * written in the text notify the whole channel — so every {@code @} gets a zero-width space after
   * it, and the Markdown a ride name might contain is escaped.
   */
  private String mattermost(
      String title, String body, @Nullable String link, @Nullable String cta) {
    StringBuilder text = new StringBuilder("**").append(mattermostEscape(title)).append("**\n");
    text.append(mattermostEscape(body));
    if (link != null && cta != null) {
      text.append("\n<").append(link).append('|').append(mattermostEscape(cta)).append('>');
    }
    ObjectNode root = objectMapper.createObjectNode();
    root.put("text", text.toString());
    return write(root);
  }

  /** Markdown emphasis and code markers escaped, Slack's control characters too, mentions broken. */
  static String mattermostEscape(String text) {
    return slackEscape(text).replaceAll("([\\\\*_~`\\[\\]])", "\\\\$1").replace("@", "@\u200B");
  }

  private String discord(String title, String body, @Nullable String link) {
    String content = "**" + title + "**\n" + body + (link != null ? "\n" + link : "");
    if (content.length() > DISCORD_MAX) {
      content = content.substring(0, DISCORD_MAX - 1) + "…";
    }
    ObjectNode root = objectMapper.createObjectNode();
    root.put("content", content);
    // Nobody is pinged, whatever a ride name or a comment contains: no @everyone by accident.
    root.putObject("allowed_mentions").putArray("parse");
    return write(root);
  }

  /** The three characters Slack's mrkdwn treats as control. */
  static String slackEscape(String text) {
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
  }

  private String write(ObjectNode root) {
    try {
      return objectMapper.writeValueAsString(root);
    } catch (JacksonException e) {
      throw new IllegalStateException(e);
    }
  }
}

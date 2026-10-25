package fr.pedalons.service.feedback;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.feedback.ErrorOccurrence;
import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.domain.feedback.FeedbackReport;
import fr.pedalons.dto.feedback.request.ClientContextDto;
import fr.pedalons.dto.feedback.request.ClientErrorDto;
import fr.pedalons.dto.feedback.request.ClientLogEntryDto;
import fr.pedalons.enums.FeedbackKind;
import fr.pedalons.repository.feedback.ErrorOccurrenceRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Turns feedback rows into GitHub issues and comments — in French, for the maintainers who triage
 * them.
 *
 * <p>The member is named by id and domain only, never by address: whoever qualifies the issue looks
 * them up in the database if they need to. The member's message is redacted here, the rest was when
 * it was stored.
 */
@ApplicationScoped
public class FeedbackIssueRenderer {

  /** GitHub refuses a body over 65 536 characters. The log is cut first, oldest entries first. */
  static final int MAX_BODY = 60_000;

  private static final int TITLE_EXCERPT = 80;
  private static final DateTimeFormatter DATE =
      DateTimeFormatter.ofPattern("d MMM yyyy HH:mm", Locale.FRENCH)
          .withZone(ZoneId.of("Europe/Paris"));

  @Inject ObjectMapper objectMapper;

  public record Issue(String title, String body, List<String> labels) {}

  public Issue feedback(FeedbackReport report, @Nullable Integer signatureIssue) {
    ClientContextDto context = read(report.getContext(), ClientContextDto.class);
    @Nullable ClientErrorDto error =
        report.getError() == null ? null : read(report.getError(), ClientErrorDto.class);
    @Nullable String message =
        report.getMessage() == null ? null : LogRedactor.redact(report.getMessage());
    String kind = report.getKind() == FeedbackKind.BUG ? "Bug" : "Suggestion";
    String platform = report.getPlatform().name().toLowerCase(Locale.ROOT);

    StringBuilder head = new StringBuilder();
    head.append(message == null ? "_Pas de description du membre._" : quote(message))
        .append("\n\n");
    head.append(contextTable(context, report.getDomain().getDomain(), report.getUser().getId()));
    head.append(
        row(
            "Signalement",
            code(TsidUtils.toString(report.getId())) + " · " + date(report.getCreatedAt())));
    head.append('\n');
    if (error != null) {
      head.append("### Erreur\n\n");
      if (signatureIssue != null) {
        head.append("Remontée automatique de la même erreur : #")
            .append(signatureIssue)
            .append("\n\n");
      }
      head.append(errorBlock(error));
    }
    if (report.getLogs() == null) {
      head.append("_Le membre n'a pas joint les informations techniques._\n");
    }
    String body = withLogs(head.toString(), logs(report.getLogs()));
    return new Issue(
        "[" + kind + "][" + platform + "] " + excerpt(title(message, error, context)),
        body,
        List.of(
            "feedback", kind.toLowerCase(Locale.ROOT), platform, report.getDomain().getDomain()));
  }

  /** The member's words; without them, the error they reported from, or the screen at least. */
  private static String title(
      @Nullable String message, @Nullable ClientErrorDto error, ClientContextDto context) {
    if (message != null) {
      return message;
    }
    if (error != null) {
      return error.type() + ": " + error.message();
    }
    return context.route() == null ? "Sans description" : "Sans description, " + context.route();
  }

  public Issue signature(ErrorSignature signature, ErrorOccurrence occurrence) {
    ClientContextDto context = read(occurrence.getContext(), ClientContextDto.class);
    ClientErrorDto error = read(occurrence.getError(), ClientErrorDto.class);
    String platform = signature.getPlatform().name().toLowerCase(Locale.ROOT);

    StringBuilder head = new StringBuilder();
    head.append("Remontée automatique d'une erreur non gérée, empreinte ")
        .append(code(signature.getFingerprint().substring(0, 12)))
        .append(
            ". Les occurrences suivantes sont récapitulées une fois par jour en commentaire.\n\n");
    head.append(
        contextTable(context, occurrence.getDomain().getDomain(), occurrence.getUser().getId()));
    head.append(row("Première occurrence", date(signature.getFirstSeenAt())));
    head.append(row("Occurrences", String.valueOf(signature.getOccurrenceCount())));
    head.append('\n');
    head.append("### Erreur\n\n").append(errorBlock(error));
    String body = withLogs(head.toString(), logs(occurrence.getLogs()));
    return new Issue(
        "[crash][" + platform + "] " + excerpt(signature.getTitle()),
        body,
        // The signature spans domains; the label is the one of the occurrence shown, which tells
        // staging from prod when both publish to the same repository.
        List.of("crash", platform, occurrence.getDomain().getDomain()));
  }

  public String summary(Instant since, ErrorOccurrenceRepository.Summary summary) {
    return "**+"
        + summary.occurrences()
        + " occurrence"
        + (summary.occurrences() > 1 ? "s" : "")
        + "** depuis le "
        + date(since)
        + ", "
        + summary.users()
        + " membre"
        + (summary.users() > 1 ? "s" : "")
        + ". Versions : "
        + String.join(", ", summary.versions())
        + ".";
  }

  public String regression(ErrorSignature signature) {
    return "Réapparue en version **"
        + signature.getRegressionVersion()
        + "** après la fermeture de l'issue (versions connues à la fermeture : "
        + String.join(", ", signature.getVersionsAtClose())
        + "). Rouverte automatiquement.";
  }

  public String linkedFeedback(int feedbackIssue) {
    return "Un membre a signalé cette erreur : #" + feedbackIssue;
  }

  // ------------------------------------------------------------------ blocks

  private String contextTable(ClientContextDto c, String domain, Long userId) {
    StringBuilder t = new StringBuilder("| | |\n|---|---|\n");
    String version = c.appVersion() + (c.buildNumber() == null ? "" : " (" + c.buildNumber() + ")");
    t.append(row("Plateforme", c.platform().name().toLowerCase(Locale.ROOT)));
    t.append(row("Version", version));
    t.append(row("OS", c.osVersion()));
    t.append(row("Appareil", c.device()));
    t.append(row("Navigateur", c.userAgent()));
    t.append(row("Écran", c.route() == null ? null : code(c.route())));
    t.append(row("Équipe", c.teamSlug()));
    t.append(row("Langue / fuseau", join(c.locale(), c.timezone())));
    t.append(row("Domaine", domain));
    t.append(row("Membre", code(TsidUtils.toString(userId))));
    return t.toString();
  }

  private String errorBlock(ClientErrorDto error) {
    StringBuilder b = new StringBuilder();
    b.append("**")
        .append(cell(error.type()))
        .append("** : ")
        .append(cell(error.message()))
        .append("\n\n");
    if (error.stack() != null && !error.stack().isBlank()) {
      b.append(details("Pile d'appels", error.stack()));
    }
    return b.toString();
  }

  /** Appends as many of the most recent log entries as the body limit allows. */
  private String withLogs(String head, List<ClientLogEntryDto> logs) {
    if (logs.isEmpty()) {
      return head;
    }
    List<String> lines = new ArrayList<>();
    for (ClientLogEntryDto e : logs) {
      lines.add(e.ts() + " " + e.level() + " [" + e.source() + "] " + e.message());
    }
    int budget = MAX_BODY - head.length() - 200;
    int from = 0;
    int size = lines.stream().mapToInt(l -> l.length() + 1).sum();
    while (from < lines.size() && size > budget) {
      size -= lines.get(from).length() + 1;
      from++;
    }
    if (from == lines.size()) {
      return head;
    }
    String summary =
        "Journal ("
            + (lines.size() - from)
            + " entrées"
            + (from > 0 ? ", " + from + " plus anciennes coupées" : "")
            + ")";
    return head + details(summary, String.join("\n", lines.subList(from, lines.size())));
  }

  private static String details(String summary, String content) {
    String fence = fence(content);
    return "<details><summary>"
        + summary
        + "</summary>\n\n"
        + fence
        + "\n"
        + content
        + "\n"
        + fence
        + "\n</details>\n\n";
  }

  /** A fence longer than any backtick run of the content, so a log cannot close it. */
  private static String fence(String content) {
    int longest = 0;
    int run = 0;
    for (char ch : content.toCharArray()) {
      run = ch == '`' ? run + 1 : 0;
      longest = Math.max(longest, run);
    }
    char[] f = new char[Math.max(3, longest + 1)];
    Arrays.fill(f, '`');
    return new String(f);
  }

  private static String row(String label, @Nullable String value) {
    return value == null || value.isBlank() ? "" : "| " + label + " | " + cell(value) + " |\n";
  }

  private static String cell(String value) {
    return value.replace("|", "\\|").replaceAll("\\R", " ");
  }

  private static String quote(String message) {
    return "> " + message.strip().replaceAll("\\R", "\n> ");
  }

  private static String code(String s) {
    return "`" + s.replace("`", "'") + "`";
  }

  private static @Nullable String join(@Nullable String a, @Nullable String b) {
    if (a == null) {
      return b;
    }
    return b == null ? a : a + " · " + b;
  }

  static String excerpt(String text) {
    String line = text.strip().replaceAll("\\s+", " ");
    return line.length() <= TITLE_EXCERPT ? line : line.substring(0, TITLE_EXCERPT - 1) + "…";
  }

  private static String date(Instant instant) {
    return DATE.format(instant);
  }

  private <T> T read(JsonNode node, Class<T> type) {
    try {
      return objectMapper.treeToValue(node, type);
    } catch (Exception e) {
      throw new IllegalStateException("Unreadable stored " + type.getSimpleName(), e);
    }
  }

  private List<ClientLogEntryDto> logs(@Nullable JsonNode node) {
    if (node == null || !node.isArray()) {
      return List.of();
    }
    List<ClientLogEntryDto> entries = new ArrayList<>();
    for (JsonNode entry : node) {
      entries.add(read(entry, ClientLogEntryDto.class));
    }
    return entries;
  }
}

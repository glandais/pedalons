package fr.pedalons.service.feedback;

import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.common.exception.ValidationException;
import fr.pedalons.domain.feedback.ErrorOccurrence;
import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.domain.feedback.FeedbackReport;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.feedback.request.ClientContextDto;
import fr.pedalons.dto.feedback.request.ClientErrorDto;
import fr.pedalons.dto.feedback.request.ClientLogEntryDto;
import fr.pedalons.dto.feedback.request.ErrorReportRequest;
import fr.pedalons.dto.feedback.request.FeedbackRequest;
import fr.pedalons.enums.FeedbackKind;
import fr.pedalons.repository.feedback.ErrorOccurrenceRepository;
import fr.pedalons.repository.feedback.ErrorSignatureRepository;
import fr.pedalons.repository.feedback.FeedbackReportRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Receives what the clients send about bugs: a member's written report, and the automatic report
 * of an unhandled error. Both are stored, redacted, and left {@code PENDING} for {@link
 * FeedbackGithubWorker} to publish — nothing here talks to GitHub.
 */
@ApplicationScoped
public class FeedbackService {

  /** How long an automatic error report is kept. Its signature, and its issue, stay. */
  static final int OCCURRENCE_RETENTION_DAYS = 90;

  /** How long a member's written report is kept once published. */
  static final int REPORT_RETENTION_DAYS = 365;

  /** Longest error message kept for an issue title. */
  private static final int TITLE_LENGTH = 300;

  @ConfigProperty(name = "pedalons.feedback.max-per-window", defaultValue = "5")
  int maxPerWindow;

  @ConfigProperty(name = "pedalons.feedback.rate-limit-window-minutes", defaultValue = "60")
  int windowMinutes;

  @ConfigProperty(name = "pedalons.feedback.errors.max-per-hour", defaultValue = "20")
  int maxErrorsPerHour;

  @Inject PedalonsQueryContext pedalonsContext;
  @Inject ObjectMapper objectMapper;
  @Inject FeedbackReportRepository feedbackReportRepository;
  @Inject ErrorSignatureRepository errorSignatureRepository;
  @Inject ErrorOccurrenceRepository errorOccurrenceRepository;

  /**
   * Files a member's report.
   *
   * @throws TooManyRequestsException {@code FEEDBACK_RATE_LIMITED} past the per-member quota. A
   *     person does not write five bug reports an hour; a script does, and every one of them is an
   *     issue someone has to read.
   * @throws ValidationException {@code VALIDATION} for a suggestion without a message. A bug may
   *     come without one: the member who hit it may not know what happened.
   */
  @Logged
  @Transactional
  public void submit(FeedbackRequest request) {
    @Nullable String message = request.message() == null ? null : request.message().strip();
    if (request.kind() == FeedbackKind.SUGGESTION && message == null) {
      throw new ValidationException(ErrorCode.VALIDATION, null, null);
    }
    User user = pedalonsContext.getUser();
    Instant now = Instant.now();
    long recent =
        feedbackReportRepository.countByUserSince(
            user.getId(), now.minus(windowMinutes, ChronoUnit.MINUTES));
    if (recent >= maxPerWindow) {
      Log.warnf(
          "Feedback rate limit exceeded for user=%d (%d in %d min)",
          user.getId(), recent, windowMinutes);
      throw new TooManyRequestsException(
          ErrorCode.FEEDBACK_RATE_LIMITED, Duration.ofMinutes(windowMinutes).toSeconds());
    }

    ClientContextDto context = redact(request.context());
    @Nullable ClientErrorDto error = request.error() == null ? null : redact(request.error());

    FeedbackReport report = new FeedbackReport();
    report.setDomain(pedalonsContext.getDomain());
    report.setUser(user);
    report.setKind(request.kind());
    report.setPlatform(context.platform());
    report.setMessage(message);
    report.setContext(objectMapper.valueToTree(context));
    report.setError(error == null ? null : objectMapper.valueToTree(error));
    report.setLogs(request.logs() == null ? null : logs(request.logs()));
    if (error != null) {
      // Only an error already reported automatically: a written report never creates a signature,
      // or the daily cap on crash issues could be spent by hand.
      String fingerprint =
          ErrorFingerprint.compute(
              context.platform(), error.type(), error.message(), error.stack());
      errorSignatureRepository.findByFingerprint(fingerprint).ifPresent(report::setSignature);
    }
    feedbackReportRepository.persist(report);
  }

  /**
   * Records an unhandled error a client caught. Silent past the per-member quota: a client stuck in
   * an error loop must neither be told to retry nor fill the table, and a 429 would only make it
   * log one more error.
   */
  @Logged
  @Transactional
  public void reportError(ErrorReportRequest request) {
    User user = pedalonsContext.getUser();
    Instant now = Instant.now();
    long recent =
        errorOccurrenceRepository.countByUserSince(user.getId(), now.minus(1, ChronoUnit.HOURS));
    if (recent >= maxErrorsPerHour) {
      Log.debugf(
          "Error report dropped for user=%s: %s in the last hour", user.getId(), (Object) recent);
      return;
    }

    ClientContextDto context = redact(request.context());
    ClientErrorDto error = redact(request.error());
    String fingerprint =
        ErrorFingerprint.compute(context.platform(), error.type(), error.message(), error.stack());
    String title = error.type() + ": " + error.message();
    ErrorSignature signature =
        errorSignatureRepository.lockOrCreate(
            fingerprint,
            context.platform(),
            title.length() > TITLE_LENGTH ? title.substring(0, TITLE_LENGTH) : title,
            now);

    signature.setLastSeenAt(now);
    signature.setOccurrenceCount(signature.getOccurrenceCount() + 1);
    String version = context.appVersion();
    if (!signature.getVersions().contains(version)) {
      List<String> versions = new ArrayList<>(signature.getVersions());
      versions.add(version);
      signature.setVersions(versions);
    }
    if (signature.isIssueClosed()
        && signature.getRegressionVersion() == null
        && !signature.getVersionsAtClose().contains(version)) {
      signature.setRegressionVersion(version);
    }

    ErrorOccurrence occurrence = new ErrorOccurrence();
    occurrence.setSignature(signature);
    occurrence.setDomain(pedalonsContext.getDomain());
    occurrence.setUser(user);
    occurrence.setAppVersion(version);
    occurrence.setContext(objectMapper.valueToTree(context));
    occurrence.setError(objectMapper.valueToTree(error));
    occurrence.setLogs(request.logs() == null ? null : logs(request.logs()));
    errorOccurrenceRepository.persist(occurrence);
  }

  /** Enforces the retention windows. Signatures stay: they are the memory of the issues. */
  @Transactional
  public long purgeExpired() {
    Instant now = Instant.now();
    return errorOccurrenceRepository.deleteCreatedBefore(
            now.minus(OCCURRENCE_RETENTION_DAYS, ChronoUnit.DAYS))
        + feedbackReportRepository.deleteCreatedBefore(
            now.minus(REPORT_RETENTION_DAYS, ChronoUnit.DAYS));
  }

  // ------------------------------------------------------------------ redaction

  private static ClientContextDto redact(ClientContextDto c) {
    return new ClientContextDto(
        c.platform(),
        LogRedactor.redact(c.appVersion()),
        LogRedactor.redactNullable(c.buildNumber()),
        LogRedactor.redactNullable(c.osVersion()),
        LogRedactor.redactNullable(c.device()),
        LogRedactor.redactNullable(c.userAgent()),
        c.route() == null ? null : LogRedactor.redact(stripQuery(c.route())),
        c.locale(),
        c.timezone(),
        c.teamSlug());
  }

  private static ClientErrorDto redact(ClientErrorDto e) {
    return new ClientErrorDto(
        e.type(), LogRedactor.redact(e.message()), LogRedactor.redactNullable(e.stack()));
  }

  private JsonNode logs(List<ClientLogEntryDto> entries) {
    return objectMapper.valueToTree(
        entries.stream()
            .map(
                e ->
                    new ClientLogEntryDto(
                        e.ts(), e.level(), e.source(), LogRedactor.redact(e.message())))
            .toList());
  }

  /** A route is a path: a query string is where the tokens of this API travel. */
  private static String stripQuery(String route) {
    int q = route.indexOf('?');
    int h = route.indexOf('#');
    int cut = q < 0 ? h : h < 0 ? q : Math.min(q, h);
    return cut < 0 ? route : route.substring(0, cut);
  }
}

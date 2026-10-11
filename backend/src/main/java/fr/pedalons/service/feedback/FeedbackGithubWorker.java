package fr.pedalons.service.feedback;

import fr.pedalons.common.Crons;
import fr.pedalons.domain.feedback.ErrorOccurrence;
import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.domain.feedback.FeedbackReport;
import fr.pedalons.enums.GithubSyncStatus;
import fr.pedalons.infrastructure.github.GitHubException;
import fr.pedalons.infrastructure.github.GitHubIssueClient;
import fr.pedalons.infrastructure.github.GitHubIssueClient.IssueStatus;
import fr.pedalons.repository.feedback.ErrorOccurrenceRepository;
import fr.pedalons.repository.feedback.ErrorSignatureRepository;
import fr.pedalons.repository.feedback.FeedbackReportRepository;
import fr.pedalons.service.feedback.FeedbackIssueRenderer.Issue;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.Callable;
import java.util.function.Supplier;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Publishes feedback to the private GitHub repository.
 *
 * <ul>
 *   <li>every 30 s: opens the issues of new error signatures (at most {@code
 *       max-new-issues-per-day} a day), then of members' reports, and reopens the issues of
 *       regressions;
 *   <li>daily: comments each open crash issue with what happened since, and notices the ones that
 *       were closed;
 *   <li>nightly: enforces the retention windows.
 * </ul>
 *
 * <p>No {@code @Transactional} here, as in {@code BiketeamLiveMigrationWorker}: every GitHub call
 * happens between two short transactions, never inside one. A failed call leaves the row {@code
 * PENDING} for the next tick, up to {@value #MAX_ATTEMPTS} attempts.
 *
 * <p>{@code ConcurrentExecution.SKIP} only guards one JVM, and for about a minute of a rolling
 * deploy two backends run these jobs. So each row is leased ({@code github_claimed_until}, a
 * conditional update, as {@code WeatherFetchWorker}) before its GitHub calls and given back after:
 * the other backend skips it, then finds it CREATED (docs/LEDGER_*.md ISSUE-8). And every write
 * to a signature locks it first, as {@code FeedbackService.reportError} does, so that neither loses
 * the other's columns (docs/LEDGER_*.md ISSUE-9).
 */
@ApplicationScoped
public class FeedbackGithubWorker {

  private static final Logger LOG = Logger.getLogger(FeedbackGithubWorker.class);

  static final int MAX_ATTEMPTS = 5;

  /** Far longer than the GitHub calls of one row; a worker that dies leaves it to expire. */
  static final Duration LEASE = Duration.ofMinutes(5);

  private static final int BATCH = 20;

  @ConfigProperty(name = "pedalons.feedback.errors.max-new-issues-per-day", defaultValue = "10")
  int maxNewIssuesPerDay;

  @Inject GitHubIssueClient github;
  @Inject FeedbackIssueRenderer renderer;
  @Inject FeedbackService feedbackService;
  @Inject FeedbackReportRepository feedbackReportRepository;
  @Inject ErrorSignatureRepository errorSignatureRepository;
  @Inject ErrorOccurrenceRepository errorOccurrenceRepository;

  @Scheduled(every = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    try {
      publishPending();
    } catch (Exception e) {
      LOG.error("Feedback GitHub publication failed", e);
    }
  }

  @Scheduled(
      cron = "0 0 7 * * ?",
      timeZone = Crons.ZONE,
      concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void daily() {
    try {
      summarize();
    } catch (Exception e) {
      LOG.error("Feedback GitHub daily summary failed", e);
    }
  }

  @Scheduled(cron = "0 15 4 * * ?", timeZone = Crons.ZONE)
  void purge() {
    long deleted = feedbackService.purgeExpired();
    if (deleted > 0) {
      LOG.infof("Feedback cleanup completed: %d expired rows deleted", deleted);
    }
  }

  /** One pass of the 30 s tick. Public for the tests, which run with the scheduler off. */
  public void publishPending() {
    if (!github.isConfigured()) {
      return;
    }
    // Signatures first: a report opened from an error then links to its freshly opened issue.
    for (Long id : tx(() -> errorSignatureRepository.findPendingIds(BATCH))) {
      if (!underSignatureLease(id, true, () -> publishSignature(id))) {
        break;
      }
    }
    for (Long id : tx(() -> feedbackReportRepository.findPendingIds(BATCH))) {
      underReportLease(id, () -> publishFeedback(id));
    }
    for (Long id : tx(() -> errorSignatureRepository.findRegressionIds())) {
      underSignatureLease(
          id,
          null,
          () -> {
            reopen(id);
            return null;
          });
    }
  }

  /**
   * Runs {@code work} under the signature's lease, or returns {@code whenHeld} when the other
   * backend holds it. {@code work} re-reads the row: what the lease protects is only decided once
   * it is held.
   */
  private <R> R underSignatureLease(Long id, R whenHeld, Supplier<R> work) {
    Instant until = leaseEnd();
    if (!tx(() -> errorSignatureRepository.claim(id, Instant.now(), until))) {
      return whenHeld;
    }
    try {
      return work.get();
    } finally {
      tx(() -> errorSignatureRepository.release(id, until));
    }
  }

  /** Runs {@code work} under the report's lease, or not at all when the other backend holds it. */
  private void underReportLease(Long id, Runnable work) {
    Instant until = leaseEnd();
    if (!tx(() -> feedbackReportRepository.claim(id, Instant.now(), until))) {
      return;
    }
    try {
      work.run();
    } finally {
      tx(() -> feedbackReportRepository.release(id, until));
    }
  }

  /** Millisecond precision, so that {@code release} matches it exactly once stored. */
  private static Instant leaseEnd() {
    return Instant.now().plus(LEASE).truncatedTo(ChronoUnit.MILLIS);
  }

  /**
   * @return false when the daily cap is reached, to stop the batch
   */
  private boolean publishSignature(Long id) {
    Instant startOfDay = LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC);
    if (tx(() -> errorSignatureRepository.countIssuesCreatedSince(startOfDay))
        >= maxNewIssuesPerDay) {
      LOG.warnf("Daily cap of %d new crash issues reached: signatures wait", maxNewIssuesPerDay);
      return false;
    }
    Optional<Issue> issue =
        tx(
            () -> {
              ErrorSignature signature = errorSignatureRepository.lock(id);
              if (signature == null || signature.getGithubStatus() != GithubSyncStatus.PENDING) {
                return Optional.empty();
              }
              Optional<ErrorOccurrence> latest = errorOccurrenceRepository.findLatest(id);
              if (latest.isEmpty()) {
                // Every occurrence purged before GitHub was ever configured: nothing to show.
                signature.setGithubStatus(GithubSyncStatus.FAILED);
                return Optional.empty();
              }
              return Optional.of(renderer.signature(signature, latest.get()));
            });
    if (issue.isEmpty()) {
      return true;
    }
    Instant now = Instant.now();
    try {
      int number =
          github.createIssue(issue.get().title(), issue.get().body(), issue.get().labels());
      tx(
          () -> {
            ErrorSignature signature = errorSignatureRepository.lock(id);
            signature.setGithubStatus(GithubSyncStatus.CREATED);
            signature.setGithubIssueNumber(number);
            signature.setGithubCreatedAt(now);
            signature.setSummarizedUntil(now);
            return null;
          });
      LOG.infof("Crash issue #%d opened for signature %d", number, id);
    } catch (GitHubException e) {
      LOG.warnf("Crash issue for signature %d not opened: %s", id, e.getMessage());
      tx(
          () -> {
            ErrorSignature signature = errorSignatureRepository.lock(id);
            signature.setGithubAttempts(signature.getGithubAttempts() + 1);
            if (signature.getGithubAttempts() >= MAX_ATTEMPTS) {
              signature.setGithubStatus(GithubSyncStatus.FAILED);
            }
            return null;
          });
    }
    return true;
  }

  private record PreparedFeedback(Issue issue, @Nullable Integer signatureIssue) {}

  private void publishFeedback(Long id) {
    Optional<PreparedFeedback> prepared =
        tx(
            () -> {
              FeedbackReport report = feedbackReportRepository.findById(id);
              if (report == null || report.getGithubStatus() != GithubSyncStatus.PENDING) {
                return Optional.empty();
              }
              ErrorSignature signature = report.getSignature();
              Integer signatureIssue =
                  signature != null && signature.getGithubStatus() == GithubSyncStatus.CREATED
                      ? signature.getGithubIssueNumber()
                      : null;
              return Optional.of(
                  new PreparedFeedback(renderer.feedback(report, signatureIssue), signatureIssue));
            });
    if (prepared.isEmpty()) {
      return;
    }
    Issue issue = prepared.get().issue();
    int number;
    try {
      number = github.createIssue(issue.title(), issue.body(), issue.labels());
    } catch (GitHubException e) {
      LOG.warnf("Feedback issue for report %d not opened: %s", id, e.getMessage());
      tx(
          () -> {
            FeedbackReport report = feedbackReportRepository.findById(id);
            report.setGithubAttempts(report.getGithubAttempts() + 1);
            if (report.getGithubAttempts() >= MAX_ATTEMPTS) {
              report.setGithubStatus(GithubSyncStatus.FAILED);
            }
            return null;
          });
      return;
    }
    tx(
        () -> {
          FeedbackReport report = feedbackReportRepository.findById(id);
          report.setGithubStatus(GithubSyncStatus.CREATED);
          report.setGithubIssueNumber(number);
          return null;
        });
    LOG.infof("Feedback issue #%d opened for report %d", number, id);
    Integer signatureIssue = prepared.get().signatureIssue();
    if (signatureIssue != null) {
      try {
        github.comment(signatureIssue, renderer.linkedFeedback(number));
      } catch (GitHubException e) {
        // The report's issue links to the crash issue already; the backlink is a convenience.
        LOG.warnf(
            "Backlink from #%d to #%d not posted: %s", signatureIssue, number, e.getMessage());
      }
    }
  }

  private void reopen(Long id) {
    record Regression(int number, String comment) {}
    Optional<Regression> regression =
        tx(
            () -> {
              ErrorSignature signature = errorSignatureRepository.findById(id);
              if (signature == null
                  || signature.getGithubIssueNumber() == null
                  || signature.getRegressionVersion() == null) {
                return Optional.empty();
              }
              return Optional.of(
                  new Regression(signature.getGithubIssueNumber(), renderer.regression(signature)));
            });
    if (regression.isEmpty()) {
      return;
    }
    try {
      github.reopen(regression.get().number());
      github.comment(regression.get().number(), regression.get().comment());
    } catch (GitHubException e) {
      LOG.warnf("Issue #%d not reopened: %s", regression.get().number(), e.getMessage());
      return;
    }
    tx(
        () -> {
          ErrorSignature signature = errorSignatureRepository.lock(id);
          signature.setIssueClosed(false);
          signature.setVersionsAtClose(new ArrayList<>());
          signature.setRegressionVersion(null);
          signature.setSummarizedUntil(Instant.now());
          return null;
        });
    LOG.infof("Issue #%d reopened: regression", regression.get().number());
  }

  /** The daily pass. Public for the tests. */
  public void summarize() {
    if (!github.isConfigured()) {
      return;
    }
    for (Long id : tx(() -> errorSignatureRepository.findToSummarizeIds())) {
      try {
        underSignatureLease(
            id,
            null,
            () -> {
              summarize(id);
              return null;
            });
      } catch (GitHubException e) {
        LOG.warnf("Daily summary of signature %d skipped: %s", id, e.getMessage());
      }
    }
  }

  private void summarize(Long id) {
    ErrorSignature snapshot = tx(() -> errorSignatureRepository.findById(id));
    Integer number = snapshot.getGithubIssueNumber();
    Instant since =
        snapshot.getSummarizedUntil() != null
            ? snapshot.getSummarizedUntil()
            : snapshot.getGithubCreatedAt();
    if (number == null || since == null) {
      return;
    }
    Instant now = Instant.now();
    IssueStatus status = github.status(number);

    if (status.closed()) {
      if (!snapshot.isIssueClosed()) {
        markClosed(id, status.closedAt() != null ? status.closedAt() : now, now);
      } else {
        tx(
            () -> {
              errorSignatureRepository.lock(id).setSummarizedUntil(now);
              return null;
            });
      }
      return;
    }

    ErrorOccurrenceRepository.Summary summary =
        tx(() -> errorOccurrenceRepository.summarizeSince(id, since));
    if (summary.occurrences() > 0) {
      github.comment(number, renderer.summary(since, summary));
    }
    tx(
        () -> {
          ErrorSignature signature = errorSignatureRepository.lock(id);
          signature.setSummarizedUntil(now);
          // Reopened by hand on GitHub: forget the closure.
          signature.setIssueClosed(false);
          signature.setVersionsAtClose(new ArrayList<>());
          return null;
        });
  }

  /**
   * Records that the issue was closed. The versions that appear only after {@code closedAt} are not
   * part of what the fix was about: the first of them is a regression, reopened by the next tick.
   *
   * <p>The row is locked before the occurrences are read: a report committed meanwhile would
   * otherwise be in neither the {@code versions} read here nor {@code findVersions}, and its version
   * neither covered by the closure nor flagged as a regression (docs/LEDGER_*.md ISSUE-9).
   */
  private void markClosed(Long id, Instant closedAt, Instant now) {
    tx(
        () -> {
          ErrorSignature signature = errorSignatureRepository.lock(id);
          List<String> before = errorOccurrenceRepository.findVersions(id, closedAt, false);
          List<String> newAfter = new ArrayList<>();
          for (String v : errorOccurrenceRepository.findVersions(id, closedAt, true)) {
            if (!before.contains(v)) {
              newAfter.add(v);
            }
          }
          List<String> atClose = new ArrayList<>(signature.getVersions());
          atClose.removeAll(newAfter);
          signature.setIssueClosed(true);
          signature.setVersionsAtClose(atClose);
          signature.setSummarizedUntil(now);
          if (!newAfter.isEmpty()) {
            signature.setRegressionVersion(newAfter.getFirst());
          }
          return null;
        });
  }

  private static <T> T tx(Callable<T> work) {
    return QuarkusTransaction.requiringNew().call(work);
  }
}

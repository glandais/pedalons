package fr.pedalons.service.feedback;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.feedback.request.ClientContextDto;
import fr.pedalons.dto.feedback.request.ClientErrorDto;
import fr.pedalons.dto.feedback.request.ErrorReportRequest;
import fr.pedalons.enums.ClientPlatform;
import fr.pedalons.enums.GithubSyncStatus;
import fr.pedalons.repository.feedback.ErrorOccurrenceRepository;
import fr.pedalons.repository.feedback.ErrorSignatureRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.OptimisticLockException;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.hibernate.StaleStateException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug: the GitHub worker's read-modify-write of {@link ErrorSignature} overwrites the increments of
 * a concurrent {@link FeedbackService#reportError}.
 *
 * <p>Found by the TLA+/TLC model of the feedback schedulers (FeedbackGithubWorker write
 * transactions vs. reportError under READ COMMITTED). reportError locks the row ({@code
 * ErrorSignatureRepository.lockOrCreate}, {@code FOR UPDATE}) but every worker transaction
 * (CREATED mark, attempts bump, reopen, summarize, markClosed) reads it with a plain {@code
 * findById}. The entity has neither {@code @Version} nor {@code @DynamicUpdate}, so the worker's
 * flush writes back every column it read: the interleaving read(worker) report(commit)
 * flush(worker) loses {@code occurrence_count + 1}, the new entry of {@code versions} and {@code
 * last_seen_at}.
 *
 * <p>The interleaving is driven explicitly. Transaction A mirrors the worker's CREATED mark
 * (FeedbackGithubWorker, after {@code createIssue}): it reads the signature, then waits while a
 * report of version 1.1 runs and commits, then sets the GitHub fields and commits. Today the report
 * does not block (A holds no lock) and A's UPDATE writes back {@code occurrence_count = 1} and
 * {@code versions = [1.0]}. Once fixed, either the report waits for A (pessimistic read in the
 * worker), A's stale write is rejected ({@code @Version}), or A only writes the columns it changed
 * ({@code @DynamicUpdate}): in every case the counter matches the occurrences.
 */
@QuarkusTest
class ErrorSignatureWorkerLostUpdateRaceTest extends AbstractBaseTest {

  private static final String STACK =
      """
      TypeError: Cannot read properties of undefined (reading 'name')
          at Xe (https://pedalons.fr/assets/RideDetailPage-Bx1_aZ9q.js:1:2345)
      """;

  @Inject FeedbackService feedbackService;
  @Inject ErrorSignatureRepository errorSignatureRepository;
  @Inject ErrorOccurrenceRepository errorOccurrenceRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private User user;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser("crasher@example.com", "Crasher");
  }

  @Test
  void workerWrite_doesNotOverwriteConcurrentReportError() throws Exception {
    // Seed: one occurrence on 1.0 → signature with occurrence_count = 1, versions = [1.0].
    CompletableFuture.runAsync(() -> inRequest(() -> feedbackService.reportError(report("1.0"))))
        .get(30, TimeUnit.SECONDS);
    Long id =
        QuarkusTransaction.requiringNew()
            .call(() -> errorSignatureRepository.findAll().firstResult().getId());

    CountDownLatch aRead = new CountDownLatch(1);
    CountDownLatch releaseA = new CountDownLatch(1);

    // Transaction A: the worker's CREATED mark, paused between its read and its flush.
    CompletableFuture<Void> a =
        CompletableFuture.runAsync(
            () -> {
              try {
                QuarkusTransaction.requiringNew()
                    .run(
                        () -> {
                          ErrorSignature signature = errorSignatureRepository.findById(id);
                          assertEquals(1, signature.getOccurrenceCount());
                          aRead.countDown();
                          try {
                            assertTrue(releaseA.await(30, TimeUnit.SECONDS));
                          } catch (InterruptedException e) {
                            throw new RuntimeException(e);
                          }
                          Instant now = Instant.now();
                          signature.setGithubStatus(GithubSyncStatus.CREATED);
                          signature.setGithubIssueNumber(100);
                          signature.setGithubCreatedAt(now);
                          signature.setSummarizedUntil(now);
                        });
              } finally {
                aRead.countDown();
              }
            });

    assertTrue(aRead.await(30, TimeUnit.SECONDS), "A's read did not run");
    if (a.isDone()) {
      a.get(); // surfaces A's own failure before the race is staged
    }

    // Transaction B: a report on 1.1 between A's read and A's flush.
    CompletableFuture<Void> b =
        CompletableFuture.runAsync(
            () -> inRequest(() -> feedbackService.reportError(report("1.1"))));
    try {
      b.get(3, TimeUnit.SECONDS); // today B commits at once: A holds no lock
    } catch (TimeoutException expectedOncePessimistic) {
      // With a FOR UPDATE read in the worker, B waits for A.
    }
    releaseA.countDown();
    try {
      a.get(30, TimeUnit.SECONDS);
    } catch (ExecutionException e) {
      // With @Version, A's stale write is rejected: an acceptable outcome of the fix.
      if (!isOptimisticFailure(e)) {
        throw e;
      }
    }
    b.get(30, TimeUnit.SECONDS);

    ErrorSignature after =
        QuarkusTransaction.requiringNew().call(() -> errorSignatureRepository.findById(id));
    long occurrences =
        QuarkusTransaction.requiringNew()
            .call(() -> errorOccurrenceRepository.count("signature.id", id));
    assertEquals(2, occurrences);
    assertEquals(
        occurrences,
        after.getOccurrenceCount(),
        "occurrence_count lost the concurrent report's increment");
    assertEquals(List.of("1.0", "1.1"), after.getVersions(), "versions lost 1.1");
  }

  private static boolean isOptimisticFailure(Throwable t) {
    for (Throwable c = t; c != null; c = c.getCause()) {
      if (c instanceof OptimisticLockException || c instanceof StaleStateException) {
        return true;
      }
    }
    return false;
  }

  private static ErrorReportRequest report(String version) {
    return new ErrorReportRequest(
        new ClientContextDto(
            ClientPlatform.WEB,
            version,
            null,
            null,
            null,
            "Mozilla/5.0",
            "/teams/team1",
            "fr",
            "Europe/Paris",
            "team1"),
        new ClientErrorDto("TypeError", "Cannot read properties of undefined", STACK),
        null);
  }

  /** Runs {@code body} on this thread in a fresh request context, as the test user. */
  private void inRequest(Runnable body) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      pedalonsContext.setUserForTest(user);
      body.run();
    } finally {
      requestContext.terminate();
    }
  }
}

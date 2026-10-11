package fr.pedalons.service.feedback;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.domain.feedback.FeedbackReport;
import fr.pedalons.dto.feedback.request.ClientContextDto;
import fr.pedalons.dto.feedback.request.ClientErrorDto;
import fr.pedalons.dto.feedback.request.ErrorReportRequest;
import fr.pedalons.dto.feedback.request.FeedbackRequest;
import fr.pedalons.enums.ClientPlatform;
import fr.pedalons.enums.FeedbackKind;
import fr.pedalons.enums.GithubSyncStatus;
import fr.pedalons.infrastructure.github.GitHubIssueClient;
import fr.pedalons.infrastructure.github.GitHubIssueClient.IssueStatus;
import fr.pedalons.repository.feedback.ErrorSignatureRepository;
import fr.pedalons.repository.feedback.FeedbackReportRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug found by the TLA+ model of the scheduled jobs under a start-first rolling deploy (old and new
 * backends both run {@code FeedbackGithubWorker.tick()} for about a minute): the worker never
 * claims a PENDING row. {@code publishSignature} / {@code publishFeedback} check PENDING in one
 * short transaction, call {@code github.createIssue} outside any transaction, and write CREATED
 * only afterwards. A second instance whose tick lands inside that GitHub call re-reads the row as
 * PENDING and opens a second issue; the last writer's issue number wins, the other issue is
 * orphaned (and, for a report linked to a signature, the backlink comment is posted twice).
 *
 * <p>The interleaving is driven explicitly, without timing assumptions: instance A's {@code
 * publishPending()} blocks inside {@code createIssue} (mocked) until released; instance B's {@code
 * publishPending()} then runs to completion (or, if a fix makes it wait on a lock, for a grace
 * delay); only then is A released. On the current code B calls {@code createIssue} too, so it is
 * called twice. Any claim (conditional UPDATE to PUBLISHING, {@code for update skip locked} held
 * across the call, an advisory lock) makes it exactly once.
 */
@QuarkusTest
class FeedbackGithubWorkerDoublePublishRaceTest extends AbstractResourceTest {

  private static final String WEB_STACK =
      """
      TypeError: Cannot read properties of undefined (reading 'name')
          at Xe (https://pedalons.fr/assets/RideDetailPage-Bx1_aZ9q.js:1:2345)
          at Yf (https://pedalons.fr/assets/index-C9aa0Zz1.js:4:111)
      """;

  @InjectMock GitHubIssueClient github;

  @Inject FeedbackGithubWorker worker;
  @Inject FeedbackReportRepository feedbackReportRepository;
  @Inject ErrorSignatureRepository errorSignatureRepository;

  private ExecutorService executor;
  private CountDownLatch firstCallEntered;
  private CountDownLatch releaseFirstCall;
  private AtomicInteger calls;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    executor = Executors.newFixedThreadPool(2);
    firstCallEntered = new CountDownLatch(1);
    releaseFirstCall = new CountDownLatch(1);
    calls = new AtomicInteger();
    when(github.isConfigured()).thenReturn(true);
    when(github.status(anyInt())).thenReturn(new IssueStatus(false, null));
    // The first createIssue (instance A) blocks, as a ~1 s GitHub call would; later ones return.
    when(github.createIssue(anyString(), anyString(), anyList()))
        .thenAnswer(
            i -> {
              int n = calls.incrementAndGet();
              if (n == 1) {
                firstCallEntered.countDown();
                releaseFirstCall.await(30, TimeUnit.SECONDS);
              }
              return 100 + n - 1;
            });
  }

  @AfterEach
  void tearDown() {
    releaseFirstCall.countDown();
    executor.shutdownNow();
  }

  // ------------------------------------------------------------------ fixtures

  private static ClientContextDto web() {
    return new ClientContextDto(
        ClientPlatform.WEB,
        "abc123",
        null,
        null,
        null,
        "Mozilla/5.0",
        "/teams/team1",
        "fr",
        "Europe/Paris",
        "team1");
  }

  private void post(String path, Object body) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(body)
        .when()
        .post(path)
        .then()
        .statusCode(204);
  }

  /** Instance A enters createIssue and stays there; instance B runs a whole tick meanwhile. */
  private void runOverlappingTicks() throws Exception {
    Future<?> instanceA = executor.submit(() -> worker.publishPending());
    assertTrue(
        firstCallEntered.await(30, TimeUnit.SECONDS), "instance A never reached createIssue");

    Future<?> instanceB = executor.submit(() -> worker.publishPending());
    try {
      instanceB.get(5, TimeUnit.SECONDS);
    } catch (TimeoutException e) {
      // A fix that makes B wait on a lock held by A: let A finish, then B.
    }
    releaseFirstCall.countDown();
    instanceA.get(30, TimeUnit.SECONDS);
    instanceB.get(30, TimeUnit.SECONDS);
  }

  // ------------------------------------------------------------------ tests

  @Test
  void pendingSignature_twoOverlappingTicks_openOneCrashIssue() throws Exception {
    post(
        "/api/feedback/errors",
        new ErrorReportRequest(
            web(),
            new ClientErrorDto("TypeError", "Cannot read properties of undefined", WEB_STACK),
            null));
    List<ErrorSignature> before =
        QuarkusTransaction.requiringNew().call(() -> errorSignatureRepository.listAll());
    assertEquals(1, before.size());
    assertEquals(GithubSyncStatus.PENDING, before.getFirst().getGithubStatus());

    runOverlappingTicks();

    // Today: 2 — both instances open an issue for the same signature.
    verify(github, times(1)).createIssue(anyString(), anyString(), anyList());
    ErrorSignature after =
        QuarkusTransaction.requiringNew().call(() -> errorSignatureRepository.listAll()).getFirst();
    assertEquals(GithubSyncStatus.CREATED, after.getGithubStatus());
  }

  @Test
  void pendingReport_twoOverlappingTicks_openOneFeedbackIssue() throws Exception {
    post(
        "/api/feedback",
        new FeedbackRequest(
            FeedbackKind.BUG, "La page de la sortie reste blanche", web(), null, null));
    List<FeedbackReport> before =
        QuarkusTransaction.requiringNew().call(() -> feedbackReportRepository.listAll());
    assertEquals(1, before.size());
    assertEquals(GithubSyncStatus.PENDING, before.getFirst().getGithubStatus());

    runOverlappingTicks();

    // Today: 2 — both instances open an issue for the same report.
    verify(github, times(1)).createIssue(anyString(), anyString(), anyList());
    FeedbackReport after =
        QuarkusTransaction.requiringNew().call(() -> feedbackReportRepository.listAll()).getFirst();
    assertEquals(GithubSyncStatus.CREATED, after.getGithubStatus());
  }
}

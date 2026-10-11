package fr.pedalons.service.user;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.domain.user.UserExport;
import fr.pedalons.enums.UserExportStatus;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.user.UserExportRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug found by the formal model of the export scheduler (TLA+ model of {@code
 * UserExportService.processOnePendingExport} / {@code retryPendingEmails}): a failed "export ready"
 * e-mail throws away the finished GDPR export.
 *
 * <p>{@code markReady} commits READY, then {@code sendExportReady} throws inside the same try as
 * the build. The catch calls {@code markFailed} (READY → PENDING, storageKey nulled) and {@code
 * safeDelete} removes the uploaded zip, so {@code retryPendingEmails} — which only looks at READY
 * rows with no emailSentAt — never sees it. After {@code pedalons.export.max-attempts} ticks with
 * SMTP down, the export ends FAILED. The code comment promises the opposite: "a mail failure must
 * not roll back a good export".
 */
@QuarkusTest
class UserExportMailFailureKeepsArchiveTest extends AbstractBaseTest {

  @Inject UserExportService userExportService;
  @Inject UserExportRepository userExportRepository;
  @Inject StorageService storageService;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  @InjectMock UserExportEmailService exportEmailService;

  private Domain domain;
  private User user;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser(domain, "owner@example.com", "Owner");
    context.setUserForTest(user);
  }

  private void smtpDown() {
    doThrow(new RuntimeException("SMTP relay timeout"))
        .when(exportEmailService)
        .sendExportReady(any(), anyString(), any(Instant.class), anyLong());
  }

  private List<Long> unsentEmailIds() {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                userExportRepository.findWithUnsentEmail().stream()
                    .map(UserExport::getId)
                    .toList());
  }

  @Test
  void aFailedReadyMail_keepsTheExportReadyAndItsArchive() {
    smtpDown();
    UserExport queued = dataService.createUserExport(domain, user);

    userExportService.processOnePendingExport();

    UserExport after = dataService.reloadUserExport(queued.getId());
    assertEquals(
        UserExportStatus.READY,
        after.getStatus(),
        "a mail failure must not roll back a good export (errorMessage="
            + after.getErrorMessage()
            + ")");
    assertNotNull(after.getStorageKey(), "the archive key must be kept");
    assertTrue(storageService.exists(after.getStorageKey()), "the archive must still be stored");
    assertNull(after.getEmailSentAt());
    assertTrue(
        unsentEmailIds().contains(queued.getId()),
        "retryPendingEmails must be able to pick the row up");
  }

  @Test
  void onceSmtpIsBack_retryPendingEmailsDeliversTheLink() {
    smtpDown();
    UserExport queued = dataService.createUserExport(domain, user);
    userExportService.processOnePendingExport();

    reset(exportEmailService); // SMTP back: sendExportReady now succeeds
    userExportService.retryPendingEmails();

    verify(exportEmailService, times(1))
        .sendExportReady(any(), anyString(), any(Instant.class), anyLong());
    UserExport after = dataService.reloadUserExport(queued.getId());
    assertEquals(UserExportStatus.READY, after.getStatus());
    assertNotNull(after.getEmailSentAt());
    assertNotNull(after.getStorageKey());
    assertTrue(storageService.exists(after.getStorageKey()));
  }

  /** With SMTP down for several ticks, the export is neither rebuilt nor ends FAILED. */
  @Test
  void smtpDownForSeveralTicks_neverEndsFailed() {
    smtpDown();
    UserExport queued = dataService.createUserExport(domain, user);

    for (int tick = 0; tick < 3; tick++) {
      userExportService.processOnePendingExport();
    }

    UserExport after = dataService.reloadUserExport(queued.getId());
    assertNotEquals(UserExportStatus.FAILED, after.getStatus());
    assertEquals(UserExportStatus.READY, after.getStatus());
    assertEquals(1, after.getAttempts(), "a built export must not be rebuilt for a mail failure");
  }
}

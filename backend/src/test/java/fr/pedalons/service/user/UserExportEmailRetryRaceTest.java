package fr.pedalons.service.user;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TokenUtils;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.domain.user.UserExport;
import fr.pedalons.dto.users.response.DownloadableExport;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug (schedulers, found by the TLA+ model of the export job's two schedulers during a rolling
 * start-first deploy): {@link UserExportService#processOnePendingExport} commits READY with
 * {@code emailSentAt} null in {@code markReady}, then sends the mail and only afterwards calls
 * {@code markEmailSent}. While instance A blocks on SMTP, instance B's tick runs {@link
 * UserExportService#retryPendingEmails}: {@code findWithUnsentEmail} has no age guard and the
 * rotation only checks {@code status == READY}, so B overwrites the token hash and sends a second
 * mail. The link in A's mail (token T1) then 404s.
 *
 * <p>The interleaving is driven explicitly: A's {@code markReady} with hash(T1), then B's {@code
 * retryPendingEmails}, before A's mail and {@code markEmailSent}.
 */
@QuarkusTest
class UserExportEmailRetryRaceTest extends AbstractBaseTest {

  @Inject UserExportService userExportService;
  @Inject StorageService storageService;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject MockMailbox mailbox;

  private Domain domain;
  private User user;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    mailbox.clear();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser(domain, "owner@example.com", "Owner");
    context.setUserForTest(user);
  }

  @Test
  void retryPendingEmails_whileTheFirstMailIsInFlight_mustNotSupersedeTheFirstLink()
      throws Exception {
    UserExport queued = dataService.createUserExport(domain, user);
    long exportId = queued.getId();
    assertTrue(userExportService.claimNextPending().isPresent());

    byte[] archive = "fake zip".getBytes(StandardCharsets.UTF_8);
    String storageKey = "exports/race-test/" + exportId + ".zip";
    storageService.store(
        storageKey, new ByteArrayInputStream(archive), "application/zip", archive.length);

    // Instance A: markReady commits READY + hash(T1), emailSentAt still null. A is now blocked in
    // exportEmailService.sendExportReady(ctx, T1, ...).
    String t1 = TokenUtils.generateSecureToken();
    Instant expiresAt = Instant.now().plus(7, ChronoUnit.DAYS);
    userExportService.markReady(
        exportId, storageKey, archive.length, TokenUtils.hashToken(t1), expiresAt);

    // Instance B's scheduler tick runs during A's SMTP round trip.
    userExportService.retryPendingEmails();

    // B must leave a just-finished export alone: A is about to deliver its mail.
    assertEquals(
        0,
        mailbox.getMailMessagesSentTo("owner@example.com").size(),
        "retryPendingEmails sent a second 'export ready' mail for an export whose first mail was"
            + " still in flight");

    // A's mail (carrying T1) is delivered, then A marks it sent.
    userExportService.markEmailSent(exportId);

    // The link in the first (and only) mail must still work.
    DownloadableExport download = assertDoesNotThrow(() -> userExportService.download(t1));
    try (InputStream in = download.content()) {
      assertArrayEquals(archive, in.readAllBytes());
    } finally {
      storageService.delete(storageKey);
    }
  }
}

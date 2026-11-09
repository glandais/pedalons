package fr.pedalons.infrastructure.email;

import io.quarkus.logging.Log;
import io.quarkus.mailer.Mail;
import io.quarkus.mailer.reactive.ReactiveMailer;
import io.quarkus.qute.Engine;
import io.quarkus.qute.Template;
import io.vertx.core.Context;
import io.vertx.core.Vertx;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * Renders {@code templates/mail/<name>.<lang>.{html,txt}} with Qute and hands the result to the
 * Quarkus mailer. Where that mail goes is the deployment's business alone: Scaleway Transactional
 * Email's SMTP relay in production, mailpit on a workstation, the mock mailbox in tests. The
 * templates in this repository are the only copy there is.
 */
@ApplicationScoped
public class EmailService {

  public static final String EMAIL_VERIFICATION = "email-verification";
  public static final String OTP = "otp";
  public static final String PASSWORD_RESET = "password-reset";
  public static final String DATA_EXPORT = "data-export";
  public static final String AD_CONTACT = "ad-contact";

  /**
   * The two invitation templates: "you already have an account, sign in" and "create one" differ
   * enough in wording that two files read better than one with a flag.
   */
  public static final String TEAM_INVITATION = "team-invitation";

  public static final String TEAM_INVITATION_SIGNUP = "team-invitation-signup";

  /**
   * The one template every notification type shares. Its parameters arrive already rendered
   * ({@code subject}, {@code title}, {@code body}, {@code ctaLabel}, {@code ctaUrl}…) by {@code
   * NotificationTexts}, so a new notification type needs no new template.
   */
  public static final String NOTIFICATION = "notification";

  /**
   * The daily digest: several notifications in one e-mail. {@code items} is a list of already
   * rendered {@code title}, {@code body}, {@code ctaLabel}, {@code ctaUrl}.
   */
  public static final String NOTIFICATION_DIGEST = "notification-digest";

  /** The languages {@code templates/mail} is translated into; anything else falls back to French. */
  private static final Set<String> TEMPLATE_LANGUAGES = Set.of("fr", "en");

  /**
   * The reactive mailer, subscribed on {@link #sendContext} and awaited here — see {@link #send}.
   * The blocking {@code Mailer} subscribes on the calling worker thread, which leaves no room for
   * choosing the context.
   */
  @Inject ReactiveMailer mailer;

  @Inject Vertx vertx;

  /**
   * How long a send may take before failing: the same setting the blocking mailer reads, since this
   * class now does its waiting itself.
   */
  @ConfigProperty(name = "quarkus.mailer.timeout", defaultValue = "60s")
  Duration timeout;

  /**
   * The one event loop every send starts on. The Vert.x mail client (4.5.x) installs a new
   * connection's socket handler only once the pool has handed the connection over, possibly on
   * another event loop: a server greeting read in between is dropped, and the send waits forever
   * on a connection it keeps leased. Sends started from worker threads — this service's callers —
   * hit it on a cold pool: on the e2e stack, 10 concurrent sign-ups right after a restart lost 8 or
   * 9 sends one round in 5. Started on a single event loop, the connection is created and
   * initialised on the thread that reads its socket, so the greeting cannot fall in between. The
   * sends themselves stay concurrent: the loop only starts them. Fixed upstream in vertx-mail-client
   * (the connection buffers what arrives before init); drop this once Quarkus ships it.
   */
  private volatile @Nullable Context sendContext;

  @Inject Engine engine;

  public void sendEmail(
      String toEmail, String templateName, String language, Map<String, Object> params) {
    sendEmail(toEmail, templateName, language, params, null);
  }

  /**
   * Sends a template, optionally asking replies to go somewhere other than the no-reply sender.
   *
   * <p>Every other email this service sends is a notification nobody answers, so {@code replyTo}
   * stayed null until the classified-ad relay needed it: the whole point of relaying a message is
   * that the recipient can answer the person who wrote it without either address having been
   * published.
   *
   * <p>The subject lives in a hidden fragment of the {@code .txt} file rather than the {@code
   * .html} one because Qute escapes everything in an HTML template, and these subjects interpolate
   * user-chosen names.
   */
  public void sendEmail(
      String toEmail,
      String templateName,
      String language,
      Map<String, Object> params,
      @Nullable String replyTo) {
    String lang = TEMPLATE_LANGUAGES.contains(language) ? language : "fr";
    String path = "mail/" + templateName + "." + lang;

    // The suffix is explicit: quarkus.qute.suffixes would otherwise resolve "mail/otp.fr" to the
    // .html file and the .txt sibling would be unreachable.
    Template textTemplate = engine.getTemplate(path + ".txt");
    Template htmlTemplate = engine.getTemplate(path + ".html");
    if (textTemplate == null || htmlTemplate == null) {
      throw new IllegalArgumentException("Unknown template: " + templateName + " / " + language);
    }

    // strip(): the newline that follows the hidden subject fragment is still part of the body.
    // Line breaks become spaces: the subject interpolates names the API takes with line breaks in
    // them, and the mail client refuses a subject holding CR or LF rather than send it — no header
    // injection, but a mail lost (docs/LEDGER_*.md SEC-33).
    String subject =
        textTemplate
            .getFragment("subject")
            .data("params", params)
            .render()
            .replaceAll("\\R+", " ")
            .strip();
    String text = textTemplate.data("params", params).render().strip() + "\n";
    String html = htmlTemplate.data("params", params).render();

    // Both parts, so plain-text readers and spam filters each get something.
    Mail mail = Mail.withHtml(toEmail, subject, html).setText(text);
    if (replyTo != null) {
      mail.setReplyTo(replyTo);
    }
    long start = System.nanoTime();
    try {
      send(mail);
    } catch (RuntimeException e) {
      // Logged here rather than left to the caller: when the send outlasts the client, the request
      // is gone by the time the exception surfaces and the exception mapper writes nothing.
      Log.errorf(
          e,
          "Mail %s not sent after %d ms",
          templateName,
          Duration.ofNanos(System.nanoTime() - start).toMillis());
      throw e;
    }
  }

  private Context sendContext() {
    Context context = sendContext;
    if (context == null) {
      synchronized (this) {
        context = sendContext;
        if (context == null) {
          // From a worker thread, a new event-loop context: kept, so every send starts on it.
          context = vertx.getOrCreateContext();
          sendContext = context;
        }
      }
    }
    return context;
  }

  private void send(Mail mail) {
    Context context = sendContext();
    CompletableFuture<Void> sending = new CompletableFuture<>();
    // Vert.x's own hop, not Mutiny's runSubscriptionOn: Mutiny decorates the task with context
    // propagation, which carried the caller's JTA transaction onto the event loop. A caller
    // inside @Transactional (an invitation) then sometimes committed while that thread was still
    // in the transaction — Narayana rolled it back (ARJUNA016053) and the request answered 500.
    // Subscribed from the event loop, the send captures no context of the caller.
    context.runOnContext(ignored ->
        mailer
            .send(mail)
            .subscribe()
            .with(done -> sending.complete(null), sending::completeExceptionally));
    try {
      sending.get(timeout.toMillis(), TimeUnit.MILLISECONDS);
    } catch (TimeoutException e) {
      sending.cancel(true);
      throw new IllegalStateException("Mail not sent within " + timeout, e);
    } catch (ExecutionException e) {
      throw e.getCause() instanceof RuntimeException runtime
          ? runtime
          : new IllegalStateException(e.getCause());
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new IllegalStateException(e);
    }
  }
}

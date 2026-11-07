package fr.pedalons.service.notification;

import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.infrastructure.email.EmailService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Map;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * The {@link NotificationChannel#EMAIL} channel: renders the texts and hands them to the generic
 * {@code notification} template.
 *
 * <p>Off unless {@code pedalons.notifications.email.enabled} says otherwise. Turning it on in
 * production writes to every member whose defaults include e-mail — a product decision.
 */
@ApplicationScoped
public class EmailNotificationSender implements NotificationChannelSender {

  @ConfigProperty(name = "pedalons.notifications.email.enabled", defaultValue = "false")
  boolean enabled;

  @Inject EmailService emailService;
  @Inject NotificationTexts texts;

  @Override
  public NotificationChannel channel() {
    return NotificationChannel.EMAIL;
  }

  @Override
  public boolean isEnabled() {
    return enabled;
  }

  @Override
  public void send(NotificationMessage message) {
    NotificationTexts.Rendered rendered = texts.render(message);
    emailService.sendEmail(
        message.recipientEmail(),
        EmailService.NOTIFICATION,
        NotificationTexts.language(message.recipientLanguage()),
        Map.of(
            "appName", message.siteName(),
            "recipientName", message.recipientName(),
            "subject", rendered.subject(),
            "title", rendered.title(),
            "preheader", rendered.preheader(),
            "body", rendered.body(),
            "ctaLabel", rendered.cta(),
            "ctaUrl", message.subjectUrl(),
            "preferencesUrl", message.preferencesUrl()));
  }
}

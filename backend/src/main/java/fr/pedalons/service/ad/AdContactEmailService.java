package fr.pedalons.service.ad;

import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.email.EmailService;
import fr.pedalons.infrastructure.i18n.LanguageResolver;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.ResolvedSite;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Map;

/**
 * Builds and sends the "someone is writing about your ad" email.
 *
 * <p>Unlike the auth emails, the recipient here has an account, so the language comes from
 * <em>their</em> preference rather than from the sender's request — the person reading the message
 * is not the person who triggered it. Only when they never chose one does it fall back on the
 * request's language.
 */
@ApplicationScoped
public class AdContactEmailService {

  @Inject EmailService emailService;

  @Inject DomainResolver domainResolver;

  @Inject LanguageResolver languageResolver;

  public void sendContactMessage(Ad ad, User author, User sender, String message) {
    ResolvedSite site = domainResolver.getResolvedSite();
    // contracts/routes.yaml declares this route in both locales, and both routers register every
    // variant — RouteGenerator on the web, _perLocale in router.dart on mobile — so one form
    // resolves whatever language the reader is in. Emitting the canonical English path keeps the
    // route table from being duplicated here, where nothing would keep the copy in step.
    String adUrl =
        "%s/teams/%s/classifieds/%s"
            .formatted(site.effectiveBaseUrl(), ad.getTeam().getSlug(), ad.getSlug());
    // The setting the footer names, as a link rather than a menu path to retrace (docs/LEDGER_*.md
    // WEB-98).
    String privacyUrl = site.effectiveBaseUrl() + "/profile/privacy";

    // The sender's address as Reply-To is the whole mechanism: the author answers the buyer
    // directly, and the buyer's address reaches the author only because the buyer chose to write.
    // That is a one-way disclosure by a deliberate act — categorically unlike publishing a contact
    // field to every member of the team, which is what this endpoint exists to avoid.
    emailService.sendEmail(
        author.getEmail(),
        EmailService.AD_CONTACT,
        author.getLanguage() != null ? author.getLanguage() : languageResolver.getLanguage(),
        Map.of(
            "appName", site.effectiveName(),
            "recipientName", author.getDisplayName(),
            "senderName", sender.getDisplayName(),
            "adName", ad.getName(),
            "adUrl", adUrl,
            "privacyUrl", privacyUrl,
            "message", message),
        sender.getEmail());
  }
}

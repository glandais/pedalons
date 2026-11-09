package fr.pedalons.service.bootstrap;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.PlatformRole;
import fr.pedalons.repository.platform.DomainRepository;
import fr.pedalons.repository.user.UserRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Locale;
import org.jboss.logging.Logger;

/**
 * Ensures a default {@link Domain} and a {@link PlatformRole#PLATFORM_ADMIN} {@link User} exist on
 * startup. Idempotent: existing rows are reused. No-op when {@code pedalons.bootstrap.enabled} is
 * false or required config is blank.
 */
@ApplicationScoped
public class BootstrapService {

  private static final Logger LOG = Logger.getLogger(BootstrapService.class);

  @Inject BootstrapConfig config;
  @Inject DomainRepository domainRepository;
  @Inject UserRepository userRepository;

  /** The default domain and its platform administrator. */
  public record Identity(Domain domain, User admin) {}

  void onStart(@Observes StartupEvent ev) {
    if (!config.enabled()) {
      LOG.debug("Bootstrap disabled");
      return;
    }
    if (config.domain().isBlank() || config.adminEmail().isBlank()) {
      LOG.info("Bootstrap skipped: pedalons.bootstrap.domain or admin-email is blank");
      return;
    }
    try {
      ensureDomainAndAdmin();
    } catch (Exception e) {
      LOG.error("Bootstrap failed", e);
    }
  }

  /**
   * Creates the default domain and its platform admin if they are missing, and returns them either
   * way. Idempotent.
   */
  public Identity ensureDomainAndAdmin() {
    if (config.domain().isBlank() || config.adminEmail().isBlank()) {
      throw new IllegalStateException(
          "pedalons.bootstrap.domain and pedalons.bootstrap.admin-email are required");
    }
    return QuarkusTransaction.requiringNew().call(this::createOrUpdate);
  }

  private Identity createOrUpdate() {
    Domain domain =
        domainRepository
            .findByDomain(config.domain())
            .orElseGet(() -> {
              LOG.infof(
                  "Creating bootstrap domain '%s' (name='%s', baseUrl='%s')",
                  config.domain(), config.domainName(), config.baseUrl());
              Domain d = new Domain(config.domain(), config.domainName(), config.baseUrl());
              domainRepository.persistAndFlush(d);
              return d;
            });

    String email = config.adminEmail().toLowerCase(Locale.ROOT);
    User admin =
        userRepository
            .findByEmailAndDomain(domain.getId(), email)
            .orElseGet(() -> {
              LOG.infof("Creating bootstrap admin '%s' on domain '%s'", email, domain.getDomain());
              User u = new User(domain, email, config.adminDisplayName());
              u.setEmailVerified(true);
              u.setEmailVerifiedAt(Instant.now());
              userRepository.persist(u);
              return u;
            });

    if (!admin.isPlatformAdmin()) {
      admin.setPlatformRole(PlatformRole.PLATFORM_ADMIN);
      userRepository.persist(admin);
    }
    return new Identity(domain, admin);
  }
}

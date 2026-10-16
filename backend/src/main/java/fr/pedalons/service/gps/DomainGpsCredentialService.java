package fr.pedalons.service.gps;

import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import fr.pedalons.repository.gps.DomainGpsCredentialRepository;
import fr.pedalons.service.security.DomainResolver;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * Service for accessing domain-specific GPS service credentials. Provides access to OAuth
 * client_id/client_secret for each GPS service configured for the current domain.
 */
@ApplicationScoped
public class DomainGpsCredentialService {

  @Inject DomainGpsCredentialRepository credentialRepository;

  @Inject DomainResolver domainResolver;

  @Inject TokenEncryptionService encryptionService;

  /**
   * Get GPS credentials for the specified service type for the current domain.
   *
   * @param serviceType The GPS service type
   * @return Optional containing credentials if configured and active
   */
  public Optional<DomainGpsCredential> getCredentials(GpsServiceType serviceType) {
    return getCredentials(domainResolver.getDomainId(), serviceType);
  }

  /**
   * The same for an explicit domain: for a caller outside an HTTP request — the background route
   * synchronisation (docs/LEDGER_*.md API-120), the account erasure job — which the request-scoped
   * {@link DomainResolver} cannot serve.
   */
  public Optional<DomainGpsCredential> getCredentials(Long domainId, GpsServiceType serviceType) {
    return credentialRepository.findByDomainAndServiceType(domainId, serviceType);
  }

  /**
   * Decrypt the client secret from a credential entity.
   *
   * @param credential The credential containing the encrypted secret
   * @return Decrypted client secret, or null if not set
   */
  public @Nullable String getDecryptedClientSecret(DomainGpsCredential credential) {
    byte[] encrypted = credential.getClientSecretEncrypted();
    if (encrypted == null) {
      return null;
    }
    return encryptionService.decrypt(encrypted);
  }

  /**
   * Get all GPS service types that have credentials configured for the current domain.
   *
   * @return List of available GPS service types
   */
  public List<GpsServiceType> getAvailableServices() {
    Long domainId = domainResolver.getDomainId();
    return credentialRepository.findAvailableServiceTypes(domainId);
  }

  /**
   * Check if a GPS service is available (has credentials configured) for the current domain.
   *
   * @param serviceType The GPS service type to check
   * @return true if credentials are configured and active
   */
  public boolean isServiceAvailable(GpsServiceType serviceType) {
    return getCredentials(serviceType).isPresent();
  }
}

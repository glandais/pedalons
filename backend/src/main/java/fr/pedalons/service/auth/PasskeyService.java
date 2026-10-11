package fr.pedalons.service.auth;

import com.webauthn4j.WebAuthnManager;
import com.webauthn4j.converter.AttestedCredentialDataConverter;
import com.webauthn4j.converter.util.ObjectConverter;
import com.webauthn4j.credential.CredentialRecord;
import com.webauthn4j.credential.CredentialRecordImpl;
import com.webauthn4j.data.*;
import com.webauthn4j.data.attestation.AttestationObject;
import com.webauthn4j.data.attestation.authenticator.AttestedCredentialData;
import com.webauthn4j.data.attestation.statement.COSEAlgorithmIdentifier;
import com.webauthn4j.data.client.Origin;
import com.webauthn4j.data.client.challenge.Challenge;
import com.webauthn4j.data.client.challenge.DefaultChallenge;
import com.webauthn4j.server.ServerProperty;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.auth.Passkey;
import fr.pedalons.domain.auth.WebAuthnChallenge;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.auth.response.PasskeyDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.WebAuthnChallengeType;
import fr.pedalons.repository.auth.PasskeyRepository;
import fr.pedalons.repository.auth.WebAuthnChallengeRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.ResolvedSite;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class PasskeyService {

  private static final SecureRandom SECURE_RANDOM = new SecureRandom();

  private final WebAuthnManager webAuthnManager = WebAuthnManager.createNonStrictWebAuthnManager();
  private final ObjectConverter objectConverter = new ObjectConverter();
  private final AttestedCredentialDataConverter attestedCredentialDataConverter =
      new AttestedCredentialDataConverter(objectConverter);

  @Inject PasskeyRepository passkeyRepository;
  @Inject WebAuthnChallengeRepository challengeRepository;
  @Inject UserRepository userRepository;
  @Inject DomainResolver domainResolver;
  @Inject PedalonsQueryContext pedalonsContext;

  @ConfigProperty(name = "pedalons.auth.webauthn.challenge-expiry-minutes", defaultValue = "5")
  int challengeExpiryMinutes;

  @Transactional
  @Logged
  public Map<String, Object> generateRegistrationOptions() {
    User user = pedalonsContext.getUser();
    // Clean up old challenges
    challengeRepository.deleteByUserId(user.getId());

    // Generate challenge
    byte[] challengeBytes = new byte[32];
    SECURE_RANDOM.nextBytes(challengeBytes);
    String challengeBase64 = Base64.getUrlEncoder().withoutPadding().encodeToString(challengeBytes);

    // Store challenge
    WebAuthnChallenge challenge =
        new WebAuthnChallenge(
            user,
            null,
            challengeBase64,
            WebAuthnChallengeType.REGISTRATION,
            Instant.now().plus(Duration.ofMinutes(challengeExpiryMinutes)));
    challengeRepository.persist(challenge);

    // Get existing credential IDs to exclude
    List<Map<String, Object>> excludeCredentials =
        passkeyRepository.findByUserId(user.getId()).stream()
            .map(
                p ->
                    Map.<String, Object>of(
                        "type",
                        "public-key",
                        "id",
                        Base64.getUrlEncoder().withoutPadding().encodeToString(p.getCredentialId()),
                        "transports",
                        p.getTransports() != null ? p.getTransports() : List.of()))
            .toList();

    // Build registration options
    ResolvedSite site = domainResolver.getResolvedSite();
    Map<String, Object> options = new LinkedHashMap<>();
    options.put("challenge", challengeBase64);
    options.put(
        "rp",
        Map.of(
            "id", site.effectiveHost(),
            "name", site.effectiveName()));
    options.put(
        "user",
        Map.of(
            "id",
                Base64.getUrlEncoder()
                    .withoutPadding()
                    .encodeToString(user.getId().toString().getBytes()),
            "name", user.getEmail(),
            "displayName", user.getDisplayName()));
    options.put(
        "pubKeyCredParams",
        List.of(
            Map.of("type", "public-key", "alg", -7), // ES256
            Map.of("type", "public-key", "alg", -257) // RS256
            ));
    options.put("timeout", 60000);
    options.put("attestation", "none");
    options.put(
        "authenticatorSelection",
        Map.of(
            "residentKey", "preferred",
            "userVerification", "preferred"));
    if (!excludeCredentials.isEmpty()) {
      options.put("excludeCredentials", excludeCredentials);
    }

    return options;
  }

  @Transactional
  @Logged
  public PasskeyDto verifyRegistration(Map<String, Object> response, @Nullable String deviceName) {
    User user = pedalonsContext.getUser();
    // Get stored challenge
    WebAuthnChallenge storedChallenge =
        challengeRepository
            .findValidByUserIdAndType(user.getId(), WebAuthnChallengeType.REGISTRATION)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));

    // Consumed in a separate transaction (survives verification failure), and single use only if
    // this request is the one whose delete hit the row (docs/LEDGER_*.md SEC-37).
    String challengeValue = storedChallenge.getChallenge();
    Long challengeId = storedChallenge.getId();
    if (!QuarkusTransaction.requiringNew().call(() -> challengeRepository.consume(challengeId))) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    try {
      @SuppressWarnings("unchecked")
      Map<String, Object> responseInner = (Map<String, Object>) response.get("response");
      // Parse the registration response
      String clientDataJSON = (String) responseInner.get("clientDataJSON");
      String attestationObject = (String) responseInner.get("attestationObject");
      @SuppressWarnings("unchecked")
      List<String> transports = (List<String>) responseInner.get("transports");

      byte[] clientDataJSONBytes = Base64.getUrlDecoder().decode(clientDataJSON);
      byte[] attestationObjectBytes = Base64.getUrlDecoder().decode(attestationObject);

      // Build registration data
      RegistrationRequest registrationRequest =
          new RegistrationRequest(attestationObjectBytes, clientDataJSONBytes);

      RegistrationData registrationData = webAuthnManager.parse(registrationRequest);

      // Verify the registration
      ResolvedSite site = domainResolver.getResolvedSite();
      Challenge challenge = new DefaultChallenge(Base64.getUrlDecoder().decode(challengeValue));
      ServerProperty serverProperty =
          ServerProperty.builder()
              .origins(buildOrigins(site))
              .rpId(site.effectiveHost())
              .challenge(challenge)
              .build();

      List<PublicKeyCredentialParameters> pubKeyCredParams =
          List.of(
              new PublicKeyCredentialParameters(
                  PublicKeyCredentialType.PUBLIC_KEY, COSEAlgorithmIdentifier.ES256),
              new PublicKeyCredentialParameters(
                  PublicKeyCredentialType.PUBLIC_KEY, COSEAlgorithmIdentifier.RS256));

      RegistrationParameters registrationParameters =
          new RegistrationParameters(serverProperty, pubKeyCredParams, false, true);

      webAuthnManager.verify(registrationData, registrationParameters);

      // Extract credential data
      AttestationObject attestation = registrationData.getAttestationObject();
      if (attestation == null) {
        throw new BadRequestException(ErrorCode.BAD_REQUEST);
      }

      AttestedCredentialData credentialData =
          attestation.getAuthenticatorData().getAttestedCredentialData();
      if (credentialData == null) {
        throw new BadRequestException(ErrorCode.BAD_REQUEST);
      }

      byte[] credentialId = credentialData.getCredentialId();
      byte[] publicKeyBytes = attestedCredentialDataConverter.convert(credentialData);
      byte[] aaguid = credentialData.getAaguid().getBytes();

      // Check if credential already exists
      if (passkeyRepository.existsByCredentialId(credentialId)) {
        throw new BadRequestException(ErrorCode.ALREADY_REGISTERED);
      }

      // Create and save passkey
      Passkey passkey = new Passkey(user, credentialId, publicKeyBytes);
      passkey.setTransports(transports);
      passkey.setDeviceName(deviceName);
      passkey.setAaguid(aaguid);
      passkey.setSignCount(attestation.getAuthenticatorData().getSignCount());
      passkeyRepository.persist(passkey);

      return PasskeyDto.from(passkey);

    } catch (BadRequestException e) {
      throw e;
    } catch (Exception e) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST, e);
    }
  }

  @Transactional
  @Public
  public Map<String, Object> generateAuthenticationOptions(@Nullable String email) {
    // Clean up old challenges if email provided
    if (email != null) {
      challengeRepository.deleteByEmail(email);
    }

    // Generate challenge
    byte[] challengeBytes = new byte[32];
    SECURE_RANDOM.nextBytes(challengeBytes);
    String challengeBase64 = Base64.getUrlEncoder().withoutPadding().encodeToString(challengeBytes);

    // Get allowed credentials if email provided
    List<Map<String, Object>> allowCredentials = new ArrayList<>();
    User user = null;

    if (email != null) {
      Domain domain = domainResolver.getDomain();
      user = userRepository.findByEmailAndDomain(domain.getId(), email).orElse(null);
      if (user != null) {
        allowCredentials =
            passkeyRepository.findByUserId(user.getId()).stream()
                .map(
                    p ->
                        Map.<String, Object>of(
                            "type",
                            "public-key",
                            "id",
                            Base64.getUrlEncoder()
                                .withoutPadding()
                                .encodeToString(p.getCredentialId()),
                            "transports",
                            p.getTransports() != null ? p.getTransports() : List.of()))
                .toList();
      }
    }

    // Store challenge
    WebAuthnChallenge challenge =
        new WebAuthnChallenge(
            user,
            email,
            challengeBase64,
            WebAuthnChallengeType.AUTHENTICATION,
            Instant.now().plus(Duration.ofMinutes(challengeExpiryMinutes)));
    challengeRepository.persist(challenge);

    // Build authentication options
    Map<String, Object> options = new LinkedHashMap<>();
    options.put("challenge", challengeBase64);
    options.put("timeout", 60000);
    options.put("rpId", domainResolver.getEffectiveHost());
    options.put("userVerification", "preferred");
    if (!allowCredentials.isEmpty()) {
      options.put("allowCredentials", allowCredentials);
    }

    return options;
  }

  @Transactional
  public User verifyAuthentication(Map<String, Object> response) {
    try {
      @SuppressWarnings("unchecked")
      Map<String, Object> responseInner = (Map<String, Object>) response.get("response");
      // Parse the authentication response
      String credentialIdBase64 = (String) response.get("id");
      String clientDataJSON = (String) responseInner.get("clientDataJSON");
      String authenticatorData = (String) responseInner.get("authenticatorData");
      String signature = (String) responseInner.get("signature");
      String userHandle = (String) responseInner.get("userHandle");

      byte[] credentialId = Base64.getUrlDecoder().decode(credentialIdBase64);
      byte[] clientDataJSONBytes = Base64.getUrlDecoder().decode(clientDataJSON);
      byte[] authenticatorDataBytes = Base64.getUrlDecoder().decode(authenticatorData);
      byte[] signatureBytes = Base64.getUrlDecoder().decode(signature);

      // Find the passkey
      Passkey passkey =
          passkeyRepository
              .findByCredentialIdAndDomain(credentialId, domainResolver.getDomainId())
              .orElseThrow(() -> new NotFoundException(ErrorCode.PASSKEY_NOT_FOUND));

      // Parse the authentication request to extract the challenge
      AuthenticationRequest authenticationRequest =
          new AuthenticationRequest(
              credentialId,
              userHandle != null ? Base64.getUrlDecoder().decode(userHandle) : null,
              authenticatorDataBytes,
              clientDataJSONBytes,
              null,
              signatureBytes);

      AuthenticationData authenticationData = webAuthnManager.parse(authenticationRequest);

      // Extract challenge from clientData and find stored challenge
      String challengeFromClient =
          Base64.getUrlEncoder()
              .withoutPadding()
              .encodeToString(
                  authenticationData.getCollectedClientData().getChallenge().getValue());

      WebAuthnChallenge storedChallenge =
          challengeRepository
              .findValidByChallenge(challengeFromClient)
              .filter(c -> c.getChallengeType() == WebAuthnChallengeType.AUTHENTICATION)
              .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));

      // Consumed in a separate transaction (survives verification failure), and before the
      // verification: a concurrent request that read the same challenge finds it gone and is
      // refused, so one signed assertion opens one session (docs/LEDGER_*.md SEC-37).
      String challengeValue = storedChallenge.getChallenge();
      Long challengeId = storedChallenge.getId();
      if (!QuarkusTransaction.requiringNew().call(() -> challengeRepository.consume(challengeId))) {
        throw new BadRequestException(ErrorCode.TOKEN_INVALID);
      }

      // Build credential record from stored data
      AttestedCredentialData credentialData =
          attestedCredentialDataConverter.convert(passkey.getPublicKey());
      CredentialRecord credentialRecord =
          new CredentialRecordImpl(
              null, // attestationStatement
              null, // uvInitialized
              null, // backupEligible
              null, // backupState
              passkey.getSignCount(),
              credentialData,
              null, // authenticatorExtensions
              null, // clientData
              null, // clientExtensions
              null // transports
              );

      // Verify the authentication
      ResolvedSite site = domainResolver.getResolvedSite();
      Challenge challenge = new DefaultChallenge(Base64.getUrlDecoder().decode(challengeValue));
      ServerProperty serverProperty =
          ServerProperty.builder()
              .origins(buildOrigins(site))
              .rpId(site.effectiveHost())
              .challenge(challenge)
              .build();

      AuthenticationParameters authenticationParameters =
          new AuthenticationParameters(serverProperty, credentialRecord, null, false, true);

      webAuthnManager.verify(authenticationData, authenticationParameters);

      // Already filtered by the lookup; kept so that a change there cannot open another site.
      if (!passkey.getUser().getDomain().getId().equals(domainResolver.getDomainId())) {
        throw new ForbiddenException();
      }

      // Update sign count
      if (authenticationData.getAuthenticatorData() != null) {
        long newSignCount = authenticationData.getAuthenticatorData().getSignCount();
        passkey.recordUsage(newSignCount);
      }

      return passkey.getUser();

    } catch (ForbiddenException | BadRequestException | NotFoundException e) {
      throw e;
    } catch (Exception e) {
      throw new ForbiddenException();
    }
  }

  @Logged
  public List<PasskeyDto> listPasskeys() {
    Long userId = pedalonsContext.getUserId();
    return passkeyRepository.findByUserId(userId).stream().map(PasskeyDto::from).toList();
  }

  @Transactional
  @Logged
  public void deletePasskey(Long passkeyId) {
    Long userId = pedalonsContext.getUserId();
    Passkey passkey =
        passkeyRepository
            .findByIdAndUserId(passkeyId, userId)
            .orElseThrow(() -> new NotFoundException(ErrorCode.PASSKEY_NOT_FOUND));

    passkeyRepository.delete(passkey);
  }

  /**
   * Build the set of allowed origins for WebAuthn verification. Includes the web origin from the
   * resolved site's effective base URL, plus any Android app origins derived from SHA-256
   * certificate fingerprints (comma-separated, colon-hex format).
   */
  private Set<Origin> buildOrigins(ResolvedSite site) {
    Set<Origin> origins = new HashSet<>();
    origins.add(new Origin(site.effectiveBaseUrl()));

    String fingerprints = site.effectiveAndroidFingerprints();
    if (fingerprints != null && !fingerprints.isBlank()) {
      for (String fingerprint : fingerprints.split(",")) {
        String trimmed = fingerprint.trim();
        if (!trimmed.isEmpty()) {
          origins.add(new Origin("android:apk-key-hash:" + hexToBase64Url(trimmed)));
        }
      }
    }

    return origins;
  }

  /** Convert a colon-separated hex fingerprint (e.g. "18:A9:F7:...") to base64url (no padding). */
  private static String hexToBase64Url(String colonHex) {
    String[] parts = colonHex.split(":");
    byte[] bytes = new byte[parts.length];
    for (int i = 0; i < parts.length; i++) {
      bytes[i] = (byte) Integer.parseInt(parts[i], 16);
    }
    return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
  }
}

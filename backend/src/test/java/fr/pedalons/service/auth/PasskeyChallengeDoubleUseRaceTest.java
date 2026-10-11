package fr.pedalons.service.auth;

// Bug: a WebAuthn authentication challenge can be used twice — PasskeyService.verifyAuthentication
// deletes the challenge with `QuarkusTransaction.requiringNew().run(() ->
// challengeRepository.deleteById(challengeId))` and ignores the boolean. When a concurrent request
// (same signed assertion) commits its own delete between this request's unlocked
// findValidByChallenge and its deleteById, Panache's deleteById finds nothing, returns false, and
// verification carries on with the challenge value read earlier: two sessions for one single-use
// challenge. Found by the TLA+ model of the passkey authentication flow (lookup / delete-in-
// REQUIRES_NEW / verify as separate atomic steps, invariant "a challenge authenticates at most
// once").
//
// The interleaving is driven deterministically: a spy on WebAuthnChallengeRepository lets the real
// findValidByChallenge run, then deletes the row in its own committed transaction (the concurrent
// winner) before returning the row to verifyAuthentication.

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;

import com.webauthn4j.converter.AttestedCredentialDataConverter;
import com.webauthn4j.converter.util.ObjectConverter;
import com.webauthn4j.data.attestation.authenticator.AAGUID;
import com.webauthn4j.data.attestation.authenticator.AttestedCredentialData;
import com.webauthn4j.data.attestation.authenticator.EC2COSEKey;
import com.webauthn4j.data.attestation.statement.COSEAlgorithmIdentifier;
import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.auth.Passkey;
import fr.pedalons.domain.auth.WebAuthnChallenge;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.repository.auth.PasskeyRepository;
import fr.pedalons.repository.auth.WebAuthnChallengeRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.ResolvedSite;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.mockito.InjectSpy;
import jakarta.inject.Inject;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.Signature;
import java.security.interfaces.ECPublicKey;
import java.security.spec.ECGenParameterSpec;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

@QuarkusTest
class PasskeyChallengeDoubleUseRaceTest extends AbstractBaseTest {

  private static final Base64.Encoder B64URL = Base64.getUrlEncoder().withoutPadding();

  @Inject PasskeyService passkeyService;
  @Inject PasskeyRepository passkeyRepository;
  @InjectSpy WebAuthnChallengeRepository challengeRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private User user;
  private KeyPair keyPair;
  private byte[] credentialId;

  @BeforeEach
  void setUp() throws Exception {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createVerifiedUser("passkey-race@example.com", "Passkey Race");

    // A software authenticator: an ES256 key pair registered as the user's passkey.
    KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
    generator.initialize(new ECGenParameterSpec("secp256r1"));
    keyPair = generator.generateKeyPair();
    credentialId = new byte[16];
    new java.security.SecureRandom().nextBytes(credentialId);

    AttestedCredentialData credentialData =
        new AttestedCredentialData(
            AAGUID.ZERO,
            credentialId,
            EC2COSEKey.create((ECPublicKey) keyPair.getPublic(), COSEAlgorithmIdentifier.ES256));
    byte[] publicKeyBytes =
        new AttestedCredentialDataConverter(new ObjectConverter()).convert(credentialData);

    Long userId = user.getId();
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              User ref = passkeyRepository.getEntityManager().getReference(User.class, userId);
              Passkey passkey = new Passkey(ref, credentialId, publicKeyBytes);
              passkey.setSignCount(0);
              passkeyRepository.persist(passkey);
            });
  }

  /** Control: the software authenticator produces an assertion the service accepts. */
  @Test
  void control_validAssertionAuthenticatesOnce() throws Exception {
    Map<String, Object> assertion = signFreshChallenge(1);

    User authenticated = passkeyService.verifyAuthentication(assertion);

    assertEquals(user.getId(), authenticated.getId());
    // And a plain replay (no race) is refused, since the challenge is gone.
    assertThrows(BadRequestException.class, () -> passkeyService.verifyAuthentication(assertion));
  }

  /**
   * The concurrent winner's delete commits between this request's lookup and its own delete. The
   * request must not authenticate: the challenge it is about to consume was already consumed.
   */
  @Test
  void challengeConsumedConcurrentlyAfterLookup_isRefused() throws Exception {
    Map<String, Object> assertion = signFreshChallenge(1);

    AtomicBoolean winnerDeleted = new AtomicBoolean(false);
    Mockito.doAnswer(
            invocation -> {
              @SuppressWarnings("unchecked")
              Optional<WebAuthnChallenge> found =
                  (Optional<WebAuthnChallenge>) invocation.callRealMethod();
              // The concurrent request (same assertion) consumes the challenge and commits.
              found.ifPresent(
                  c -> {
                    Long id = c.getId();
                    QuarkusTransaction.requiringNew()
                        .run(() -> winnerDeleted.set(challengeRepository.delete("id", id) == 1));
                  });
              return found;
            })
        .when(challengeRepository)
        .findValidByChallenge(anyString());

    RuntimeException refused = null;
    User authenticated = null;
    try {
      authenticated = passkeyService.verifyAuthentication(assertion);
    } catch (BadRequestException | ForbiddenException e) {
      refused = e;
    }

    assertTrue(winnerDeleted.get(), "the simulated concurrent request consumed the challenge");
    assertNull(
        authenticated,
        "a challenge already consumed by a concurrent request authenticated a second session");
    assertNotNull(refused);
  }

  // --- software authenticator ---

  private Map<String, Object> signFreshChallenge(int signCount) throws Exception {
    Map<String, Object> options = passkeyService.generateAuthenticationOptions(null);
    String challenge = (String) options.get("challenge");

    ResolvedSite site = domainResolver.getResolvedSite();
    String clientDataJson =
        "{\"type\":\"webauthn.get\",\"challenge\":\""
            + challenge
            + "\",\"origin\":\""
            + site.effectiveBaseUrl()
            + "\",\"crossOrigin\":false}";
    byte[] clientDataBytes = clientDataJson.getBytes(StandardCharsets.UTF_8);

    byte[] rpIdHash =
        MessageDigest.getInstance("SHA-256")
            .digest(site.effectiveHost().getBytes(StandardCharsets.UTF_8));
    ByteArrayOutputStream authData = new ByteArrayOutputStream();
    authData.write(rpIdHash);
    authData.write(0x01 | 0x04); // UP | UV
    authData.write(ByteBuffer.allocate(4).putInt(signCount).array());
    byte[] authenticatorData = authData.toByteArray();

    byte[] clientDataHash = MessageDigest.getInstance("SHA-256").digest(clientDataBytes);
    Signature signer = Signature.getInstance("SHA256withECDSA");
    signer.initSign(keyPair.getPrivate());
    signer.update(authenticatorData);
    signer.update(clientDataHash);
    byte[] signature = signer.sign();

    Map<String, Object> inner = new LinkedHashMap<>();
    inner.put("clientDataJSON", B64URL.encodeToString(clientDataBytes));
    inner.put("authenticatorData", B64URL.encodeToString(authenticatorData));
    inner.put("signature", B64URL.encodeToString(signature));
    inner.put("userHandle", null);

    Map<String, Object> response = new LinkedHashMap<>();
    response.put("id", B64URL.encodeToString(credentialId));
    response.put("rawId", B64URL.encodeToString(credentialId));
    response.put("type", "public-key");
    response.put("response", inner);
    return response;
  }
}

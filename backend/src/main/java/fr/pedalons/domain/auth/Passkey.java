package fr.pedalons.domain.auth;

import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(name = "passkeys")
@NoArgsConstructor
public class Passkey {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(name = "credential_id", nullable = false, unique = true, columnDefinition = "bytea")
  private byte[] credentialId;

  @Column(name = "public_key", nullable = false, columnDefinition = "bytea")
  private byte[] publicKey;

  @Column(name = "sign_count", nullable = false)
  private long signCount = 0;

  @JdbcTypeCode(SqlTypes.ARRAY)
  @Column(name = "transports", columnDefinition = "text[]")
  private @Nullable List<String> transports;

  @Column(name = "device_name", length = 250)
  private @Nullable String deviceName;

  @Column(name = "aaguid", columnDefinition = "bytea")
  private byte @Nullable [] aaguid;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  @Column(name = "last_used_at")
  private @Nullable Instant lastUsedAt;

  public Passkey(User user, byte[] credentialId, byte[] publicKey) {
    this.user = user;
    this.credentialId = credentialId;
    this.publicKey = publicKey;
  }

  public void recordUsage(long newSignCount) {
    this.signCount = newSignCount;
    this.lastUsedAt = Instant.now();
  }
}

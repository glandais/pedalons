package fr.pedalons.infrastructure.hibernate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

import fr.pedalons.domain.auth.Passkey;
import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.hibernate.metamodel.mapping.AttributeMapping;
import org.hibernate.persister.entity.EntityPersister;
import org.hibernate.type.SqlTypes;
import org.junit.jupiter.api.Test;

/**
 * Guards the wiring that plain unit tests cannot see: Hibernate must use {@link JsonbFormatMapper}
 * (otherwise it silently falls back to its own default mapper), JsonNode columns must keep their
 * deep-copy plan, and the shared {@code List<String>} java type must not leak between the JSON and
 * ARRAY columns.
 */
@QuarkusTest
class JsonbMappingTest {

  @Inject EntityManagerFactory emf;

  private SessionFactoryImplementor sf() {
    return emf.unwrap(SessionFactory.class).unwrap(SessionFactoryImplementor.class);
  }

  private AttributeMapping attribute(Class<?> entity, String name) {
    EntityPersister persister = sf().getMappingMetamodel().getEntityDescriptor(entity.getName());
    return persister.findAttributeMapping(name);
  }

  @Test
  void persistenceUnitUsesJsonbFormatMapper() {
    assertInstanceOf(
        JsonbFormatMapper.class, sf().getSessionFactoryOptions().getJsonFormatMapper());
  }

  @Test
  void jsonNodeColumnsKeepTheirDeepCopyPlan() {
    AttributeMapping progress = attribute(BiketeamMigrationJob.class, "progress");
    assertInstanceOf(
        JsonNodeMutabilityPlan.class, progress.getAttributeMetadata().getMutabilityPlan());
  }

  @Test
  void passkeyTransportsStaysAnArray() {
    AttributeMapping transports = attribute(Passkey.class, "transports");
    assertEquals(
        SqlTypes.ARRAY, transports.getSingleJdbcMapping().getJdbcType().getDefaultSqlTypeCode());
  }

  @Test
  void errorSignatureVersionsIsJson() {
    AttributeMapping versions = attribute(ErrorSignature.class, "versions");
    assertEquals(
        SqlTypes.JSON, versions.getSingleJdbcMapping().getJdbcType().getDefaultSqlTypeCode());
  }
}

package fr.pedalons.schema;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.util.ContainerImages;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManagerFactory;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.flywaydb.core.Flyway;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.hibernate.metamodel.mapping.SelectableMapping;
import org.junit.jupiter.api.Test;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * The CHECK constraints the Flyway migrations put on enum columns hold every value of the Java enum
 * (docs/LEDGER_*.md API-72).
 *
 * <p>The other tests build their schema from the entities ({@code drop-and-create}, Flyway off): an
 * enum stored as text that gains a value without a migration widening its CHECK passes all of them,
 * then every write of the new value fails in production ({@code API-71}). This test applies {@code
 * db/migration} to an empty PostGIS database of its own, then compares each single-column CHECK
 * that lists values with the enum Hibernate maps to that column — table and column read from the
 * mapping model, so an {@code @Column} name, a single-table subclass or an embeddable are found as
 * Hibernate writes them.
 *
 * <p>A value the constraint lacks fails the test. A value the constraint keeps after the enum lost
 * it does not: during a rolling deploy the previous release may still write it, and rows may still
 * hold it.
 */
@QuarkusTest
class EnumCheckConstraintsTest extends AbstractBaseTest {

  /** Every quoted literal of a constraint definition: {@code 'OTP'::character varying}. */
  private static final Pattern LITERAL = Pattern.compile("'((?:[^']|'')*)'");

  @Inject EntityManagerFactory entityManagerFactory;

  @Test
  void everyEnumValueIsAllowedByTheMigratedCheckConstraints() throws SQLException {
    Map<String, Class<?>> enumColumns = enumColumns();
    Map<String, Set<String>> checks = migratedChecks();

    List<String> problems = new ArrayList<>();
    Set<String> compared = new TreeSet<>();
    for (Map.Entry<String, Set<String>> check : checks.entrySet()) {
      Class<?> enumType = enumColumns.get(check.getKey());
      if (enumType == null) {
        continue;
      }
      compared.add(check.getKey());
      Set<String> missing = new TreeSet<>(names(enumType));
      missing.removeAll(check.getValue());
      if (!missing.isEmpty()) {
        problems.add(
            check.getKey()
                + " ("
                + enumType.getSimpleName()
                + "): the migrated CHECK lacks "
                + missing
                + " — a migration must widen it");
      }
    }

    assertEquals(List.of(), problems, String.join("\n", problems));
    // Guards the test itself: a mapping read wrong would compare nothing and pass.
    assertTrue(
        compared.containsAll(
            Set.of(
                "auth_tokens.token_type",
                "gps_route_syncs.last_error",
                "users.unit_system",
                "users.theme")),
        "Expected constraints not compared, only " + compared);
  }

  /** {@code table.column} → enum, for every enum Hibernate stores as text. */
  private Map<String, Class<?>> enumColumns() {
    SessionFactoryImplementor sessionFactory =
        entityManagerFactory.unwrap(SessionFactoryImplementor.class);
    Map<String, Class<?>> columns = new HashMap<>();
    sessionFactory
        .getMappingMetamodel()
        .forEachEntityDescriptor(persister ->
            persister.forEachSelectable((int index, SelectableMapping selectable) -> {
              Class<?> type =
                  selectable.getJdbcMapping().getJavaTypeDescriptor().getJavaTypeClass();
              if (type.isEnum() && isText(selectable)) {
                columns.put(
                    key(
                        selectable.getContainingTableExpression(),
                        selectable.getSelectionExpression()),
                    type);
              }
            }));
    return columns;
  }

  private static boolean isText(SelectableMapping selectable) {
    int code = selectable.getJdbcMapping().getJdbcType().getDdlTypeCode();
    return code == Types.VARCHAR
        || code == Types.CHAR
        || code == Types.LONGVARCHAR
        || code == Types.NVARCHAR;
  }

  /** {@code table.column} → the values its single-column CHECK lists, after every migration. */
  private static Map<String, Set<String>> migratedChecks() throws SQLException {
    String image = ContainerImages.compose("postgres");
    try (PostgreSQLContainer postgres =
        new PostgreSQLContainer(
            DockerImageName.parse(image).asCompatibleSubstituteFor("postgres"))) {
      postgres.start();
      Flyway.configure()
          .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
          .locations("classpath:db/migration")
          .load()
          .migrate();
      Map<String, Set<String>> checks = new TreeMap<>();
      try (Connection connection =
              DriverManager.getConnection(
                  postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
          Statement statement = connection.createStatement();
          ResultSet rows =
              statement.executeQuery(
                  """
                  SELECT c.relname, a.attname, pg_get_constraintdef(con.oid)
                  FROM pg_constraint con
                  JOIN pg_class c ON c.oid = con.conrelid
                  JOIN pg_namespace n ON n.oid = c.relnamespace
                  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = con.conkey[1]
                  WHERE con.contype = 'c' AND n.nspname = 'public'
                    AND cardinality(con.conkey) = 1
                  """)) {
        while (rows.next()) {
          Set<String> values = literals(rows.getString(3));
          if (!values.isEmpty()) {
            checks
                .computeIfAbsent(key(rows.getString(1), rows.getString(2)), k -> new TreeSet<>())
                .addAll(values);
          }
        }
      }
      return checks;
    }
  }

  private static Set<String> literals(String definition) {
    Set<String> values = new TreeSet<>();
    Matcher matcher = LITERAL.matcher(definition);
    while (matcher.find()) {
      values.add(matcher.group(1).replace("''", "'"));
    }
    return values;
  }

  private static Set<String> names(Class<?> enumType) {
    return Arrays.stream(enumType.getEnumConstants())
        .map(constant -> ((Enum<?>) constant).name())
        .collect(Collectors.toSet());
  }

  private static String key(String table, String column) {
    return table + "." + column;
  }
}

package fr.pedalons.service.migration.live;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.exception.NotFoundException;
import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;

/**
 * With any of the five {@code PEDALONS_BIKETEAM_*} settings missing the feature does not exist. The
 * test context runs with all five set (application.properties, {@code %test}), so this is checked
 * without Quarkus rather than through a restart under another profile; the M2M side is in
 * BiketeamM2MFilterTest.
 */
class BiketeamMigrationDisabledTest {

  private static BiketeamLiveMigrationConfig configured() {
    BiketeamLiveMigrationConfig config = new BiketeamLiveMigrationConfig();
    config.requestKey = Optional.of(BiketeamTestTokens.KEY_BASE64);
    config.triggerSecret = Optional.of(BiketeamTestTokens.TRIGGER_SECRET);
    config.exportUrl = Optional.of("http://127.0.0.1:9");
    config.exportSecret = Optional.of("export");
    config.publicUrl = Optional.of(BiketeamTestTokens.PUBLIC_URL);
    return config;
  }

  @Test
  void allFiveSet_isEnabled() {
    assertTrue(configured().isEnabled());
  }

  @Test
  void anyOneMissingOrBlank_isDisabled() {
    for (Consumer<BiketeamLiveMigrationConfig> unset :
        List.<Consumer<BiketeamLiveMigrationConfig>>of(
            c -> c.requestKey = Optional.empty(),
            c -> c.triggerSecret = Optional.of(" "),
            c -> c.exportUrl = Optional.empty(),
            c -> c.exportSecret = Optional.empty(),
            c -> c.publicUrl = Optional.of(""))) {
      BiketeamLiveMigrationConfig config = configured();
      unset.accept(config);
      assertFalse(config.isEnabled());
    }
  }

  @Test
  void publicEndpoints_areNotFound_whenDisabled() {
    BiketeamLiveMigrationConfig config = configured();
    config.requestKey = Optional.empty();
    BiketeamMigrationGrantService service = new BiketeamMigrationGrantService();
    service.config = config;
    String token = BiketeamTestTokens.request("n-peloton").token();
    assertThrows(NotFoundException.class, () -> service.preview(token));
    assertThrows(NotFoundException.class, () -> service.confirm(token));
  }
}

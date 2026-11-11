package fr.pedalons.repository.migration;

import fr.pedalons.domain.migration.BiketeamMigrationMap;
import fr.pedalons.service.migration.BiketeamMigrationService;
import io.quarkus.hibernate.orm.panache.PanacheRepositoryBase;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class BiketeamMigrationMapRepository
    implements PanacheRepositoryBase<BiketeamMigrationMap, BiketeamMigrationMap.Key> {

  public Optional<BiketeamMigrationMap> findByBiketeamId(String entityType, String biketeamId) {
    return find("entityType = ?1 and biketeamId = ?2", entityType, biketeamId)
        .firstResultOptional();
  }

  public @Nullable Long findTriblyId(String entityType, String biketeamId) {
    return findByBiketeamId(entityType, biketeamId)
        .map(BiketeamMigrationMap::getTriblyId)
        .orElse(null);
  }

  /**
   * Whether the team came from biketeam — a {@code TEAM} row points at it, which is where biketeam
   * redirects the team's old addresses (docs/LEDGER_*.md MIG-5).
   */
  public boolean isMigratedTeam(long teamId) {
    return count("entityType = ?1 and triblyId = ?2", BiketeamMigrationService.T_TEAM, teamId) > 0;
  }

  /** Binds per statement, well under Postgres' 65535; a team holds a few thousand rows at most. */
  public static final int IN_CHUNK = 1000;

  /**
   * {@link #findTriblyId} for many ids of one type: one statement per {@value #IN_CHUNK} ids.
   *
   * @return biketeam id → Pédalons id, for the ids that have a mapping row
   */
  public Map<String, Long> findTriblyIds(String entityType, Collection<String> biketeamIds) {
    List<String> ids = List.copyOf(new java.util.LinkedHashSet<>(biketeamIds));
    Map<String, Long> found = new HashMap<>();
    for (int from = 0; from < ids.size(); from += IN_CHUNK) {
      List<String> chunk = ids.subList(from, Math.min(ids.size(), from + IN_CHUNK));
      getEntityManager()
          .createQuery(
              "select m.biketeamId, m.triblyId from BiketeamMigrationMap m"
                  + " where m.entityType = :type and m.biketeamId in :ids",
              Object[].class)
          .setParameter("type", entityType)
          .setParameter("ids", chunk)
          .getResultList()
          .forEach(row -> found.put((String) row[0], (Long) row[1]));
    }
    return found;
  }

  public @Nullable String findFingerprint(String entityType, String biketeamId) {
    return findByBiketeamId(entityType, biketeamId)
        .map(BiketeamMigrationMap::getSourceFingerprint)
        .orElse(null);
  }

  /** Leaves any recorded fingerprint alone — for rows whose source is not a file. */
  public BiketeamMigrationMap upsert(String entityType, String biketeamId, long triblyId) {
    return upsert(entityType, biketeamId, triblyId, null, null);
  }

  /**
   * A non-null {@code fingerprint} marks the row as fully built from that exact source file. Pass
   * null to leave the stored one untouched; there is no way to clear it, and nothing needs to.
   */
  public BiketeamMigrationMap upsert(
      String entityType, String biketeamId, long triblyId, @Nullable String fingerprint) {
    return upsert(entityType, biketeamId, triblyId, fingerprint, null);
  }

  /**
   * Same, recording which biketeam team the row belongs to — what the live migration writes, so
   * that setting a trashed team aside can find every row of that team. A null {@code biketeamTeamId} leaves the stored one
   * alone, which is what the former dump import did.
   */
  public BiketeamMigrationMap upsert(
      String entityType,
      String biketeamId,
      long triblyId,
      @Nullable String fingerprint,
      @Nullable String biketeamTeamId) {
    Optional<BiketeamMigrationMap> existing = findByBiketeamId(entityType, biketeamId);
    if (existing.isPresent()) {
      BiketeamMigrationMap row = existing.get();
      row.setTriblyId(triblyId);
      if (fingerprint != null) {
        row.setSourceFingerprint(fingerprint);
      }
      if (biketeamTeamId != null) {
        row.setBiketeamTeamId(biketeamTeamId);
      }
      row.touch();
      persist(row);
      return row;
    }
    BiketeamMigrationMap row = new BiketeamMigrationMap(entityType, biketeamId, triblyId);
    row.setSourceFingerprint(fingerprint);
    row.setBiketeamTeamId(biketeamTeamId);
    persist(row);
    return row;
  }

  /**
   * Forgets a biketeam team whose trashed Pédalons team is set aside: every row the live migration tagged with it, plus the
   * rows keyed by {@code keys} — the legacy import wrote no {@code biketeam_team_id}, so its rows can
   * only be found through the ids of the snapshot.
   *
   * @param keys {@code (entityType, biketeamId)} pairs, as {@link BiketeamMigrationMap.Key}
   * @return how many rows were deleted
   */
  public long deleteByTeamOrKeys(String biketeamTeamId, Collection<BiketeamMigrationMap.Key> keys) {
    long deleted = delete("biketeamTeamId", biketeamTeamId);
    // Grouped by type so the IN list stays one bind per id rather than one clause per pair.
    Map<String, List<String>> idsByType = new HashMap<>();
    for (BiketeamMigrationMap.Key key : keys) {
      idsByType
          .computeIfAbsent(key.getEntityType(), k -> new ArrayList<>())
          .add(key.getBiketeamId());
    }
    for (Map.Entry<String, List<String>> entry : idsByType.entrySet()) {
      List<String> ids = entry.getValue();
      for (int from = 0; from < ids.size(); from += IN_CHUNK) {
        List<String> chunk = ids.subList(from, Math.min(ids.size(), from + IN_CHUNK));
        deleted += delete("entityType = ?1 and biketeamId in ?2", entry.getKey(), chunk);
      }
    }
    return deleted;
  }
}

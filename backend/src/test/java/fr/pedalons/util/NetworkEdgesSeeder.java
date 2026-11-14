package fr.pedalons.util;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.repository.route.GpxTrackRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.ArrayList;
import java.util.List;

/**
 * Creates team routes that carry a street edges document (docs/LEDGER_*.md API-198, lot 3): the
 * route generator reads nothing else of them, so a route is a stub with an original GPX asset (the
 * revision the document must match) and the document of a walk on the {@link
 * NetworkEdgesFixtures} grid.
 */
@ApplicationScoped
public class NetworkEdgesSeeder {

  /** A seeded route: its id, its only track and the revision of its original. */
  public record Seeded(Route route, long trackId, long rev) {}

  @Inject TestDataService dataService;
  @Inject GpxTrackRepository trackRepository;
  @Inject EntityManager em;

  /** A route with an original but no document yet: its analysis is still running. */
  public Seeded seedPending(Team team, User user, String name) {
    Route route = dataService.createRoute(team, user, name);
    long rev =
        dataService
            .attachAsset(route, user, AssetType.ROUTE_ORIGINAL_GPX, "original.gpx")
            .getFileId();
    return new Seeded(route, route.getTracks().getFirst().getId(), rev);
  }

  /** A route whose document walks the grid through {@code xy}. */
  public Seeded seedWalk(Team team, User user, String name, int[]... xy) {
    Seeded s = seedPending(team, user, name);
    write(s.trackId(), NetworkEdgesFixtures.walk(s.rev(), xy));
    return s;
  }

  /** A route riding row {@code y} of a grid of {@code size} nodes a side. */
  public Seeded seedRow(Team team, User user, String name, int y, int size) {
    Seeded s = seedPending(team, user, name);
    write(s.trackId(), NetworkEdgesFixtures.row(s.rev(), y, size));
    return s;
  }

  /** A route riding column {@code x}. */
  public Seeded seedColumn(Team team, User user, String name, int x, int size) {
    Seeded s = seedPending(team, user, name);
    write(s.trackId(), NetworkEdgesFixtures.column(s.rev(), x, size));
    return s;
  }

  /** The 2 x size routes of a full grid, rows then columns. */
  public List<Seeded> seedGrid(Team team, User user, int size) {
    List<Seeded> out = new ArrayList<>();
    for (int i = 0; i < size; i++) {
      out.add(seedRow(team, user, "Row " + i, i, size));
    }
    for (int i = 0; i < size; i++) {
      out.add(seedColumn(team, user, "Column " + i, i, size));
    }
    return out;
  }

  /** Stores a document, in its own transaction, as the catch-up and the backfill do. */
  public void write(long trackId, NetworkEdgesDocument document) {
    QuarkusTransaction.requiringNew()
        .run(() -> trackRepository.updateNetworkEdges(trackId, document));
  }

  /**
   * What another instance, or the previous release, would do: plain SQL, nothing of ours in the way.
   */
  public void sql(String statement, Object... params) {
    QuarkusTransaction.requiringNew()
        .run(() -> {
          var q = em.createNativeQuery(statement);
          for (int i = 0; i < params.length; i++) {
            q.setParameter(i + 1, params[i]);
          }
          q.executeUpdate();
        });
  }
}

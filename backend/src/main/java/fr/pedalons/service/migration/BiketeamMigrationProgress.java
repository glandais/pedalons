package fr.pedalons.service.migration;

/**
 * What {@link BiketeamMigrationService} reports while it maps a team: the phase it is in, one tick
 * per element of that phase, a per-kind outcome count, and warnings. The live migration turns it
 * into the job's progress, counts and heartbeat.
 *
 * <p>Implementations must be cheap and must not throw, except to abort the run on purpose (a job
 * that has been taken away from this worker).
 */
public interface BiketeamMigrationProgress {

  /** The phases of a job, in order. {@code done}/{@code total} count the elements of the phase. */
  enum Phase {
    QUEUED,
    SNAPSHOT,
    TEAM,
    PLACES,
    ROUTES,
    RIDE_TEMPLATES,
    PUBLICATIONS,
    RIDES,
    TRIPS,
    URLS,
    DONE
  }

  /** The counters of the job status, one per kind of migrated content. */
  enum Counter {
    TEAM_PAGES,
    PLACES,
    ROUTES,
    RIDE_TEMPLATES,
    PUBLICATIONS,
    RIDES,
    TRIPS,
    TRIP_STAGES,
    IMAGES
  }

  enum Outcome {
    /** Created or updated — present in Pédalons after the run. */
    MIGRATED,
    /** Deleted on biketeam's side, or deliberately left out (the placeholder logo). */
    SKIPPED,
    /** This element alone failed; the team carried on. */
    FAILED
  }

  /** Warning codes, as the job status reports them. */
  final class Codes {
    public static final String GPX_MISSING = "GPX_MISSING";
    public static final String GPX_EMPTY = "GPX_EMPTY";
    public static final String GPX_FAILURE = "GPX_FAILURE";
    public static final String FILE_DOWNLOAD_FAILED = "FILE_DOWNLOAD_FAILED";
    public static final String IMAGE_FAILED = "IMAGE_FAILED";
    public static final String ITEM_FAILED = "ITEM_FAILED";

    /**
     * A trip whose stages fall outside its biketeam dates: migrated as is, but Pédalons derives the
     * trip's end from its stages, so the biketeam end date is lost and the trip may end before it
     * starts. The source is inconsistent; nothing is corrected.
     */
    public static final String TRIP_STAGES_OUTSIDE_DATES = "TRIP_STAGES_OUTSIDE_DATES";

    /**
     * A route whose biketeam tags did not all fit Pédalons' bounds (plan 2026-10-01-tags D16): a
     * label cut to 32 characters, or tags dropped beyond 10 on the route or 100 in the team. The
     * route is migrated with the first ones.
     */
    public static final String TAGS_TRUNCATED = "TAGS_TRUNCATED";

    /**
     * A route the team's visibility would lower to {@code TEAM} while a ride or a trip of Pédalons
     * that is not {@code TEAM} uses it: it keeps its visibility, as {@code RouteService.updateRoute}
     * would refuse the change (docs/LEDGER_*.md API-176, decision D6).
     */
    public static final String ROUTE_VISIBILITY_KEPT = "ROUTE_VISIBILITY_KEPT";

    private Codes() {}
  }

  /** Enters {@code phase}, which has {@code total} elements. */
  void phase(Phase phase, int total);

  /**
   * Called before each element of the current phase is processed — the moment to write a heartbeat,
   * since a single route can hold the thread for minutes.
   */
  void beforeItem();

  /** One element of the current phase is done. */
  void tick();

  /** Records {@code outcome} for one element of {@code counter}. */
  void count(Counter counter, Outcome outcome);

  /**
   * @param entityType TEAM, TEAM_PAGE, PLACE, ROUTE, RIDE_TEMPLATE, PUBLICATION, RIDE, TRIP,
   *     TRIP_STAGE, IMAGE or LOGO
   * @param code one of {@link Codes}
   */
  void warning(String entityType, String biketeamId, String code, String message);
}

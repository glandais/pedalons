package fr.pedalons.service.migration.live;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.repository.migration.BiketeamMigrationMapRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.common.SlugService;
import fr.pedalons.service.migration.BiketeamMigrationProgress.Phase;
import fr.pedalons.service.migration.BiketeamMigrationService;
import fr.pedalons.service.migration.BiketeamSource;
import fr.pedalons.service.migration.live.snapshot.BiketeamSnapshot;
import fr.pedalons.service.notification.NotificationPublisher;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.Optional;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Runs biketeam live migration jobs (docs/plans/2026-09-22-biketeam-live-migration.md §7.1).
 *
 * <p>One job per tick, and {@code SKIP}: one job at a time on the instance — the GPX pipeline is
 * heavy, and that is deliberate. No {@code @Transactional} here, as in {@code
 * UserExportScheduler}: a job spans minutes of network and GPX work, and every step opens its own
 * short transaction.
 */
@ApplicationScoped
public class BiketeamLiveMigrationWorker {

  private static final Logger LOG = Logger.getLogger(BiketeamLiveMigrationWorker.class);

  /** Opens the source of a claimed job — the export snapshot in production, a fixture in tests. */
  @FunctionalInterface
  public interface SourceFactory {
    /**
     * @param heartbeat the job's {@link JobProgressTracker#heartbeat()}, for the downloads to call
     *     as their bodies come in
     */
    BiketeamSource open(LiveJobContext ctx, Runnable heartbeat) throws IOException;
  }

  @Inject BiketeamLiveMigrationConfig config;
  @Inject BiketeamMigrationJobService jobService;
  @Inject BiketeamExportClient exportClient;
  @Inject BiketeamMigrationService migrationService;
  @Inject BiketeamTargetResolver targetResolver;
  @Inject BiketeamMigrationUrls urls;
  @Inject BiketeamMigrationMapRepository mapRepo;
  @Inject TeamRepository teamRepository;
  @Inject UserRepository userRepository;
  @Inject EntityManager em;
  @Inject DomainResolver domainResolver;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject NotificationPublisher notificationPublisher;

  @Scheduled(every = "10s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    try {
      runOne();
    } catch (Exception e) {
      // A scheduler that throws stops logging usefully; the job row already records the failure.
      LOG.error("Biketeam migration worker tick failed", e);
    }
  }

  @Scheduled(every = "5m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void recoverStuck() {
    if (!config.isEnabled()) {
      return;
    }
    try {
      int n = jobService.recoverStuck();
      if (n > 0) {
        LOG.warnf("Recovered %d stuck biketeam migration job(s)", n);
      }
    } catch (Exception e) {
      LOG.error("Biketeam migration stuck-job recovery failed", e);
    }
  }

  @Scheduled(every = "1h", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void expireGrants() {
    if (!config.isEnabled()) {
      return;
    }
    try {
      jobService.expireGrants();
    } catch (Exception e) {
      LOG.error("Biketeam migration grant expiry failed", e);
    }
  }

  /**
   * Claims and runs at most one queued job, fetching its snapshot from biketeam.
   *
   * @return whether a job was run
   */
  public boolean runOne() {
    return runOne(this::openSnapshot);
  }

  /** Same, with the source supplied — what the tests drive with a fixture snapshot. */
  public boolean runOne(SourceFactory sources) {
    if (!config.isEnabled()) {
      return false;
    }
    Optional<Long> claimed = jobService.claimNext();
    if (claimed.isEmpty()) {
      return false;
    }
    LiveJobContext ctx = jobService.loadContext(claimed.get());
    LOG.infof(
        "Biketeam migration job %s: team '%s', attempt %d (dryRun=%s, reset=%s)",
        ctx.jobTsid(), ctx.biketeamTeamId(), ctx.attempt(), ctx.dryRun(), ctx.reset());
    run(ctx, sources);
    return true;
  }

  private void run(LiveJobContext ctx, SourceFactory sources) {
    JobProgressTracker tracker =
        new JobProgressTracker(
            (progress, result) -> jobService.recordProgress(ctx, progress, result),
            jobService::toJson);
    try {
      tracker.phase(Phase.SNAPSHOT, 1);
      try (BiketeamSource source = sources.open(ctx, tracker::heartbeat)) {
        tracker.tick();
        Map<String, Map<String, String>> urlMap = execute(ctx, source, tracker);
        tracker.phase(Phase.DONE, 0);
        jobService.succeed(ctx, tracker.progressJson(), tracker.resultJson(urlMap));
        LOG.infof("Biketeam migration job %s succeeded: %s", ctx.jobTsid(), tracker.counts());
      }
    } catch (BiketeamJobLostException e) {
      LOG.warnf("Biketeam migration job %s abandoned: %s", ctx.jobTsid(), e.getMessage());
    } catch (BiketeamJobFailure e) {
      safely(() -> jobService.fail(ctx, e.code(), e.getMessage()));
    } catch (BiketeamExportException e) {
      LOG.warnf("Biketeam migration job %s: %s", ctx.jobTsid(), e.getMessage());
      if (e.kind() == BiketeamExportException.Kind.UNAVAILABLE) {
        safely(() -> jobService.retryOrFail(ctx, e.kind().errorCode(), e.getMessage()));
      } else {
        safely(() -> jobService.fail(ctx, e.kind().errorCode(), e.getMessage()));
      }
    } catch (Exception e) {
      LOG.errorf(e, "Biketeam migration job %s failed", ctx.jobTsid());
      safely(
          () ->
              jobService.retryOrFail(
                  ctx, BiketeamMigrationJobService.INTERNAL_ERROR, e.toString()));
    }
  }

  private static void safely(Runnable update) {
    try {
      update.run();
    } catch (BiketeamJobLostException e) {
      LOG.warn(e.getMessage());
    }
  }

  /** Fetches and checks the snapshot, then wraps it with a download directory of its own. */
  private BiketeamSource openSnapshot(LiveJobContext ctx, Runnable heartbeat) throws IOException {
    BiketeamSnapshot snapshot = exportClient.fetchSnapshot(ctx.biketeamTeamId(), heartbeat);
    if (snapshot.schemaVersion() != BiketeamSnapshot.SCHEMA_VERSION) {
      throw new BiketeamExportException(
          BiketeamExportException.Kind.INVALID,
          "Unsupported snapshot schemaVersion " + snapshot.schemaVersion());
    }
    if (snapshot.team() == null || !ctx.biketeamTeamId().equals(snapshot.team().id())) {
      throw new BiketeamExportException(
          BiketeamExportException.Kind.INVALID,
          "The snapshot is not of team " + ctx.biketeamTeamId());
    }
    Path tempDir = Files.createTempDirectory("biketeam-migration-" + ctx.jobTsid() + "-");
    return new SnapshotBiketeamSource(snapshot, exportClient.withHeartbeat(heartbeat), tempDir);
  }

  /**
   * Target resolution, mapping and URL table, inside a request context carrying the job's domain and
   * user, and without notifications.
   */
  Map<String, Map<String, String>> execute(
      LiveJobContext ctx, BiketeamSource source, JobProgressTracker tracker) {
    ManagedContext requestContext = Arc.container().requestContext();
    boolean activated = false;
    if (!requestContext.isActive()) {
      requestContext.activate();
      activated = true;
    }
    try {
      return notificationPublisher.silently(() -> executeInRequest(ctx, source, tracker));
    } finally {
      if (activated) {
        requestContext.terminate();
      }
    }
  }

  private record Actors(Domain domain, @Nullable User user) {}

  private Map<String, Map<String, String>> executeInRequest(
      LiveJobContext ctx, BiketeamSource source, JobProgressTracker tracker) {
    Actors actors =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    new Actors(
                        em.find(Domain.class, ctx.domainId()),
                        userRepository
                            .findActiveByIdAndDomain(ctx.domainId(), ctx.userId())
                            .orElse(null)));
    User user = actors.user();
    if (user == null) {
      throw new BiketeamJobFailure(
          BiketeamMigrationJobService.INTERNAL_ERROR,
          "The Pédalons account that confirmed the migration no longer exists");
    }
    domainResolver.setDomainForTest(actors.domain());
    pedalonsContext.setUserForTest(user);

    tracker.phase(Phase.TEAM, 1);
    Prepared prepared = QuarkusTransaction.requiringNew().call(() -> prepareTarget(ctx, source));
    if (prepared.refusal() != null) {
      throw prepared.refusal();
    }
    // The target is recorded as soon as it exists, not once the content is mapped: a later attempt
    // of this job must recognise the team it created, and not reset it again (prepareTarget).
    // The team to set aside is only trashed in the transaction that creates its successor, after
    // the slug was found free there: a conflict leaves it untouched, mapping included.
    Long setAsideId = prepared.setAsideTeamId();
    Team team =
        migrationService.migrateTeamLive(
            actors.domain(),
            user,
            source,
            prepared.expectedTeamId(),
            setAsideId == null ? null : () -> setAside(ctx, source, setAsideId),
            teamId -> jobService.setTargetTeam(ctx, teamId),
            tracker);

    tracker.phase(Phase.URLS, 1);
    Map<String, Map<String, String>> urlMap = urls.build(source, team.getId(), ctx.baseUrl());
    tracker.tick();
    return urlMap;
  }

  /**
   * What {@link #prepareTarget} decided.
   *
   * @param refusal the failure to end the job with, or null to proceed
   * @param expectedTeamId the migrated team to reuse, whatever its slug, or null to create one
   * @param setAsideTeamId the team of ours to set aside — trashed or reset — in the transaction that
   *     creates the new one, or null
   */
  private record Prepared(
      @Nullable BiketeamJobFailure refusal,
      @Nullable Long expectedTeamId,
      @Nullable Long setAsideTeamId) {
    static Prepared refuse(BiketeamJobFailure refusal) {
      return new Prepared(refusal, null, null);
    }

    static Prepared create(@Nullable Long setAsideTeamId) {
      return new Prepared(null, null, setAsideTeamId);
    }
  }

  /**
   * §7.3 of the plan, re-evaluated here because the state may have changed since the confirmation.
   * The team is found through the {@code TEAM} mapping row first ({@link BiketeamTargetResolver}),
   * so a migrated team renamed on Pédalons is still replayed — or reset — rather than duplicated.
   * Decides to set aside — trash and rename — the previous team when it came from this biketeam
   * team and is either already trashed or asked to be reset; the setting aside itself happens in
   * the transaction that creates the new team ({@code migrateTeamLive}), so nothing is trashed when
   * the slug turns out to be taken. Never touches a native team.
   *
   * <p>The reset applies once per job: when the migrated team is the one an earlier
   * attempt of this same job created ({@code ctx.targetTeamId()}), it is the reset's result, and a
   * retry resumes it instead of throwing it away — and the GPX pipeline with it. So it is when a
   * team already carries this job's set-aside slug ({@link #setAsideByThisJob}): {@code
   * target_team_id} is written in a transaction of its own, after the one that created the team,
   * and may never have been.
   *
   * <p>Nothing is written here; {@code migrateTeamLive} checks the decision again in the
   * transaction that writes the target.
   */
  private Prepared prepareTarget(LiveJobContext ctx, BiketeamSource source) {
    BiketeamTargetResolver.Target target =
        targetResolver.evaluate(ctx.domainId(), ctx.biketeamTeamId());
    switch (target.state()) {
      case MIGRATED_IN_OTHER_DOMAIN -> {
        return Prepared.refuse(
            new BiketeamJobFailure(
                "BIKETEAM_MIGRATED_IN_OTHER_DOMAIN",
                "Biketeam team '" + ctx.biketeamTeamId() + "' was migrated to another domain"));
      }
      case SLUG_CONFLICT -> {
        return Prepared.refuse(
            new BiketeamJobFailure(
                "BIKETEAM_SLUG_CONFLICT",
                "Slug '" + target.slug() + "' is taken by team '" + target.teamName() + "'"));
      }
      case NEW -> {
        return Prepared.create(target.trashed() ? target.teamId() : null);
      }
      case EXISTING_MIGRATED -> {
        Long teamId = target.teamId();
        User user =
            userRepository.findActiveByIdAndDomain(ctx.domainId(), ctx.userId()).orElse(null);
        if (teamId == null || user == null || !targetResolver.mayAdminister(user, teamId)) {
          return Prepared.refuse(
              new BiketeamJobFailure(
                  "BIKETEAM_NOT_TEAM_ADMIN",
                  "The confirming account does not administer team '" + target.teamName() + "'"));
        }
        if (ctx.reset() && !teamId.equals(ctx.targetTeamId()) && !setAsideByThisJob(ctx)) {
          if (targetResolver.isResetBlocked(teamId)) {
            return Prepared.refuse(
                new BiketeamJobFailure(
                    "BIKETEAM_RESET_BLOCKED",
                    "A domain alias is pinned on team '" + target.teamName() + "'"));
          }
          // A reset recreates the team at the biketeam slug, which the migrated team may have
          // left when renamed on Pédalons — and a native team may have taken since.
          Optional<Team> holder =
              targetResolver.slugHeldByAnotherTeam(ctx.domainId(), ctx.biketeamTeamId(), teamId);
          if (holder.isPresent()) {
            return Prepared.refuse(
                new BiketeamJobFailure(
                    "BIKETEAM_SLUG_CONFLICT",
                    "Slug '"
                        + BiketeamTargetResolver.targetSlug(ctx.biketeamTeamId())
                        + "' is taken by team '"
                        + holder.get().getName()
                        + "'"));
          }
          return Prepared.create(teamId);
        }
        if (ctx.reset()) {
          LOG.infof(
              "Biketeam migration job %s: team %d comes from an earlier attempt, reset not"
                  + " replayed",
              ctx.jobTsid(), teamId);
        }
        return new Prepared(null, teamId, null);
      }
    }
    return Prepared.create(null);
  }

  /**
   * Whether an earlier attempt of this job already set a team aside: {@link #setAsideSlug} ends with
   * the job's id, and the setting aside only commits with the creation of its successor and of its
   * {@code TEAM} mapping row. The migrated team is then that successor, even when the attempt died
   * before recording it as {@code target_team_id} (a crash, a DB blip, a lost job between the two
   * transactions): resetting it again would rename it to the slug the first team already holds —
   * {@code uk_teams_domain_slug} on every attempt — or, for a team renamed on Pédalons, throw the
   * new one away (docs/LEDGER_*.md MIG-15).
   */
  private boolean setAsideByThisJob(LiveJobContext ctx) {
    return teamRepository.existsTrashedBySlugSuffixAndDomain(
        ctx.domainId(), setAsideSuffix(ctx.jobTsid()));
  }

  /**
   * Trashes the team the way {@code TeamService.deleteTeam} does, renames its slug to free it, and
   * forgets its mapping rows — those tagged with the biketeam team, plus, for the rows the legacy
   * import wrote untagged, every key of the snapshot. Nothing is physically deleted. Runs inside
   * the transaction that creates the new team, which rolls it back on a slug conflict.
   */
  private void setAside(LiveJobContext ctx, BiketeamSource source, long teamId) {
    Team team = teamRepository.findById(teamId);
    team.setDeleted(true);
    team.setSlug(setAsideSlug(team.getSlug(), ctx.jobTsid()));
    long forgotten =
        mapRepo.deleteByTeamOrKeys(
            ctx.biketeamTeamId(), BiketeamMigrationService.mappingKeys(source));
    LOG.infof(
        "Biketeam migration job %s: set aside team %d as '%s' (%d mapping rows forgotten)",
        ctx.jobTsid(), teamId, team.getSlug(), forgotten);
  }

  /**
   * {@code <slug>-reset-<jobTsid>}, a valid Pédalons slug of at most {@link
   * SlugService#MAX_SLUG_LENGTH}: the suffix is kept whole and the old slug gives way.
   */
  static String setAsideSlug(String slug, String jobTsid) {
    String suffix = setAsideSuffix(jobTsid);
    return SlugService.truncateSlug(slug, SlugService.MAX_SLUG_LENGTH - suffix.length()) + suffix;
  }

  private static String setAsideSuffix(String jobTsid) {
    return "-reset-" + jobTsid;
  }
}

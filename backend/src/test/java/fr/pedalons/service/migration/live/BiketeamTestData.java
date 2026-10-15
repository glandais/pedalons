package fr.pedalons.service.migration.live;

import fr.pedalons.common.TokenUtils;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import fr.pedalons.domain.migration.BiketeamMigrationMap;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.BiketeamMigrationStatus;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.repository.migration.BiketeamMigrationJobRepository;
import fr.pedalons.repository.migration.BiketeamMigrationMapRepository;
import fr.pedalons.service.migration.BiketeamMigrationService;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.LocalTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/** Direct database access for the biketeam migration tests. */
@ApplicationScoped
public class BiketeamTestData {

  @Inject BiketeamMigrationJobRepository jobRepository;
  @Inject BiketeamMigrationMapRepository mapRepository;
  @Inject EntityManager em;
  @Inject PublicationEndCalculator endCalculator;

  /** Records {@code team} as migrated from biketeam team {@code biketeamTeamId}. */
  @Transactional
  public void mapTeam(String biketeamTeamId, Team team) {
    mapRepository.upsert(BiketeamMigrationService.T_TEAM, biketeamTeamId, team.getId());
  }

  /** A QUEUED job for {@code biketeamTeamId}, as if another request were in flight. */
  @Transactional
  public BiketeamMigrationJob createActiveJob(Domain domain, User user, String biketeamTeamId) {
    String requestId = UUID.randomUUID().toString();
    BiketeamMigrationJob job =
        new BiketeamMigrationJob(
            em.getReference(Domain.class, domain.getId()),
            em.getReference(User.class, user.getId()),
            biketeamTeamId,
            "Team " + biketeamTeamId,
            requestId,
            true,
            false,
            BiketeamTestTokens.PUBLIC_URL + "/" + biketeamTeamId + "/admin/pedalons/callback",
            domain.getBaseUrl(),
            TokenUtils.hashToken("bmg_" + requestId),
            Instant.now().plusSeconds(600));
    job.setStatus(BiketeamMigrationStatus.QUEUED);
    job.setQueuedAt(Instant.now());
    job.setNextAttemptAt(Instant.now());
    jobRepository.persistAndFlush(job);
    return job;
  }

  /** Turns a job RUNNING, as if claimed {@code attempts} times, last heard of at {@code heartbeatAt}. */
  @Transactional
  public void markRunning(long jobId, int attempts, @Nullable Instant heartbeatAt) {
    BiketeamMigrationJob job = jobRepository.findById(jobId);
    job.setStatus(BiketeamMigrationStatus.RUNNING);
    job.setAttempts(attempts);
    job.setStartedAt(Instant.now().minusSeconds(7200));
    job.setHeartbeatAt(heartbeatAt);
    job.setNextAttemptAt(null);
  }

  /** Puts a job in {@code status}, ended at {@code finishedAt}, its grant lapsed at {@code grantExpiresAt}. */
  @Transactional
  public void end(
      long jobId,
      BiketeamMigrationStatus status,
      @Nullable Instant finishedAt,
      Instant grantExpiresAt) {
    BiketeamMigrationJob job = jobRepository.findById(jobId);
    job.setStatus(status);
    job.setFinishedAt(finishedAt);
    job.setGrantExpiresAt(grantExpiresAt);
  }

  /** Makes a requeued job claimable right away, instead of after its retry delay. */
  @Transactional
  public void dueNow(long jobId) {
    jobRepository.findById(jobId).setNextAttemptAt(Instant.now().minusSeconds(1));
  }

  /** Maps {@code biketeamId} of {@code entityType} to {@code triblyId}. */
  @Transactional
  public void map(String entityType, String biketeamId, long triblyId) {
    mapRepository.upsert(entityType, biketeamId, triblyId);
  }

  @Transactional
  public BiketeamMigrationJob findJob(String requestId) {
    BiketeamMigrationJob job = jobRepository.findByRequestId(requestId).orElseThrow();
    em.detach(job);
    return job;
  }

  @Transactional
  public BiketeamMigrationJob findJobById(long id) {
    BiketeamMigrationJob job = jobRepository.findById(id);
    em.detach(job);
    return job;
  }

  @Transactional
  public void expireGrant(String requestId) {
    jobRepository
        .findByRequestId(requestId)
        .orElseThrow()
        .setGrantExpiresAt(Instant.now().minusSeconds(1));
  }

  @Transactional
  public long countUsers() {
    return em.createQuery("select count(u) from User u", Long.class).getSingleResult();
  }

  @Transactional
  public long countComments() {
    return em.createQuery("select count(c) from Comment c", Long.class).getSingleResult();
  }

  @Transactional
  public long countParticipations() {
    return em.createQuery("select count(p) from RideParticipation p", Long.class).getSingleResult()
        + em.createQuery("select count(p) from TripParticipation p", Long.class).getSingleResult();
  }

  @Transactional
  public List<BiketeamMigrationMap> mappingRows(String biketeamTeamId) {
    return mapRepository.list("biketeamTeamId", biketeamTeamId);
  }

  /** Overwrites the fingerprint a migrated route records, as an earlier pipeline would have left it. */
  @Transactional
  public void setRouteFingerprint(String biketeamId, @Nullable String fingerprint) {
    em.createQuery(
            "update BiketeamMigrationMap m set m.sourceFingerprint = :f"
                + " where m.entityType = :t and m.biketeamId = :b")
        .setParameter("f", fingerprint)
        .setParameter("t", BiketeamMigrationService.T_ROUTE)
        .setParameter("b", biketeamId)
        .executeUpdate();
  }

  @Transactional
  public @Nullable String routeFingerprint(String biketeamId) {
    return mapRepository.findFingerprint(BiketeamMigrationService.T_ROUTE, biketeamId);
  }

  public record TeamView(long id, String name, String slug, boolean deleted, long createdById) {}

  /** The team at {@code slug} in the domain, trashed ones included, or null. */
  @Transactional
  public TeamView team(Domain domain, String slug) {
    return em.createQuery("select t from Team t where t.domain.id = :d and t.slug = :s", Team.class)
        .setParameter("d", domain.getId())
        .setParameter("s", slug)
        .getResultStream()
        .findFirst()
        .map(
            t ->
                new TeamView(
                    t.getId(), t.getName(), t.getSlug(), t.isDeleted(), t.getCreatedBy().getId()))
        .orElse(null);
  }

  @Transactional
  public TeamView teamById(long id) {
    Team t = em.find(Team.class, id);
    return new TeamView(
        t.getId(), t.getName(), t.getSlug(), t.isDeleted(), t.getCreatedBy().getId());
  }

  @Transactional
  public TeamRole roleOf(User user, long teamId) {
    return em.createQuery(
            "select ut.role from UserTeam ut where ut.user.id = :u and ut.team.id = :t",
            TeamRole.class)
        .setParameter("u", user.getId())
        .setParameter("t", teamId)
        .getResultStream()
        .findFirst()
        .orElse(null);
  }

  /** Live team entities of a kind: 1 Route, 2 Ride… — counted by class. */
  @Transactional
  public long countLive(Class<? extends TeamEntity> type, long teamId) {
    return em.createQuery(
            "select count(e) from "
                + type.getSimpleName()
                + " e where e.team.id = :t and e.deleted = false",
            Long.class)
        .setParameter("t", teamId)
        .getSingleResult();
  }

  @Transactional
  public long countCreatedByOtherThan(long teamId, long userId) {
    return em.createQuery(
            "select count(e) from TeamEntity e where e.team.id = :t and e.createdBy.id <> :u",
            Long.class)
        .setParameter("t", teamId)
        .setParameter("u", userId)
        .getSingleResult();
  }

  public record GroupView(String name, int sortOrder, LocalTime time, Long leaderId) {}

  public record RideView(String name, Instant dateTime, long createdById, List<GroupView> groups) {}

  @Transactional
  public RideView ride(long teamId, String title) {
    Ride ride =
        em.createQuery(
                "select r from Ride r where r.team.id = :t and r.name = :n and r.deleted = false",
                Ride.class)
            .setParameter("t", teamId)
            .setParameter("n", title)
            .getSingleResult();
    List<GroupView> groups =
        ride.getGroups().stream()
            .sorted(Comparator.comparingInt(RideGroup::getSortOrder))
            .map(
                g ->
                    new GroupView(
                        g.getName(),
                        g.getSortOrder(),
                        EventTimezoneResolver.ownTime(
                            ride.getDateTime(), g.getStartAt(), ride.zone()),
                        g.getLeader() == null ? null : g.getLeader().getId()))
            .toList();
    return new RideView(ride.getName(), ride.getDateTime(), ride.getCreatedBy().getId(), groups);
  }

  /** The next number of a migrated ride template (docs/LEDGER_*.md API-108). */
  @Transactional
  public @Nullable Integer templateNextNumber(long teamId, String name) {
    return em.createQuery(
            "select t.nextNumber from RideTemplate t where t.team.id = :t and t.name = :n",
            Integer.class)
        .setParameter("t", teamId)
        .setParameter("n", name)
        .getSingleResult();
  }

  /** The end stored on a migrated ride or trip, and what the calculator makes of it now. */
  public record EndView(@Nullable Instant stored, Instant computed) {}

  @Transactional
  public EndView rideEnd(long teamId, String title) {
    Ride ride =
        em.createQuery(
                "select r from Ride r where r.team.id = :t and r.name = :n and r.deleted = false",
                Ride.class)
            .setParameter("t", teamId)
            .setParameter("n", title)
            .getSingleResult();
    return new EndView(ride.getEndDateTime(), endCalculator.rideEnd(ride));
  }

  @Transactional
  public EndView tripEnd(long teamId, String title) {
    Trip trip =
        em.createQuery(
                "select t from Trip t where t.team.id = :t and t.name = :n and t.deleted = false",
                Trip.class)
            .setParameter("t", teamId)
            .setParameter("n", title)
            .getSingleResult();
    return new EndView(trip.getEndDateTime(), endCalculator.tripEnds(trip).end());
  }

  public record StageView(String name, int sortOrder, Instant dateTime) {}

  @Transactional
  public List<StageView> stages(long teamId, String tripTitle) {
    Trip trip =
        em.createQuery(
                "select t from Trip t where t.team.id = :t and t.name = :n and t.deleted = false",
                Trip.class)
            .setParameter("t", teamId)
            .setParameter("n", tripTitle)
            .getSingleResult();
    return trip.getStages().stream()
        .filter(s -> !s.isDeleted())
        .sorted(Comparator.comparingInt(TripStage::getSortOrder))
        .map(s -> new StageView(s.getName(), s.getSortOrder(), s.getDateTime()))
        .toList();
  }

  @Transactional
  public String tripMarkdown(long teamId, String tripTitle) {
    return em.createQuery(
            "select t.markdown from Trip t where t.team.id = :t and t.name = :n"
                + " and t.deleted = false",
            String.class)
        .setParameter("t", teamId)
        .setParameter("n", tripTitle)
        .getSingleResult();
  }

  @Transactional
  public WindDirection windOf(long teamId, String routeName) {
    return em.createQuery(
            "select r.windDirection from Route r where r.team.id = :t and r.name = :n"
                + " and r.deleted = false",
            WindDirection.class)
        .setParameter("t", teamId)
        .setParameter("n", routeName)
        .getSingleResult();
  }

  @Transactional
  public List<String> teamPageNames(long teamId) {
    return em.createQuery(
            "select p.name from TeamPage p where p.team.id = :t and p.deleted = false order by"
                + " p.name",
            String.class)
        .setParameter("t", teamId)
        .getResultList();
  }

  /** Renames a team's slug directly, as its admin could on Pédalons. */
  @Transactional
  public void renameTeam(long teamId, String slug) {
    em.find(Team.class, teamId).setSlug(slug);
  }

  /** Puts a team in the trash, as its admin could on Pédalons — slug kept. */
  @Transactional
  public void trashTeam(long teamId) {
    em.find(Team.class, teamId).setDeleted(true);
  }

  public record TeamSettings(Visibility visibility, boolean joinable) {}

  @Transactional
  public TeamSettings settingsOf(long teamId) {
    Team t = em.find(Team.class, teamId);
    return new TeamSettings(t.getVisibility(), t.isJoinable());
  }

  public record TeamFlags(
      boolean enableRoutePlanner,
      boolean addMemberAllowed,
      boolean visibilityEditable,
      boolean joinable) {}

  @Transactional
  public TeamFlags flagsOf(long teamId) {
    Team t = em.find(Team.class, teamId);
    return new TeamFlags(
        t.isEnableRoutePlanner(), t.isAddMemberAllowed(), t.isVisibilityEditable(), t.isJoinable());
  }

  @Transactional
  public void setSettings(long teamId, Visibility visibility, boolean joinable) {
    Team t = em.find(Team.class, teamId);
    t.setVisibility(visibility);
    t.setJoinable(joinable);
  }

  /** Visibilities of the live routes, posts, rides and trips of a team. */
  @Transactional
  public List<Visibility> contentVisibilities(long teamId) {
    return em.createQuery(
            "select e.visibility from TeamEntity e where e.team.id = :t and e.deleted = false"
                + " and type(e) in (Route, Post, Ride, Trip)",
            Visibility.class)
        .setParameter("t", teamId)
        .getResultList();
  }

  @Transactional
  public long countTeamsCreatedBy(User user) {
    return em.createQuery("select count(t) from Team t where t.createdBy.id = :u", Long.class)
        .setParameter("u", user.getId())
        .getSingleResult();
  }

  /** Trashes every live entity of a kind in a team, as its admin could on Pédalons; their ids. */
  @Transactional
  public List<Long> trashAll(Class<? extends TeamEntity> type, long teamId) {
    List<? extends TeamEntity> live =
        em.createQuery(
                "select e from "
                    + type.getSimpleName()
                    + " e where e.team.id = :t and e.deleted = false",
                type)
            .setParameter("t", teamId)
            .getResultList();
    live.forEach(e -> e.setDeleted(true));
    return live.stream().map(TeamEntity::getId).toList();
  }

  /** Ids of the live entities of a kind in a team. */
  @Transactional
  public List<Long> liveIds(Class<? extends TeamEntity> type, long teamId) {
    return em.createQuery(
            "select e.id from "
                + type.getSimpleName()
                + " e where e.team.id = :t and e.deleted = false",
            Long.class)
        .setParameter("t", teamId)
        .getResultList();
  }

  /** The route of a ride group — id and whether it is trashed — or null when it has none. */
  public record GroupRoute(long id, boolean deleted) {}

  @Transactional
  public GroupRoute groupRoute(long teamId, String rideTitle, String groupName) {
    Ride ride =
        em.createQuery(
                "select r from Ride r where r.team.id = :t and r.name = :n and r.deleted = false",
                Ride.class)
            .setParameter("t", teamId)
            .setParameter("n", rideTitle)
            .getSingleResult();
    return ride.getGroups().stream()
        .filter(g -> g.getName().equals(groupName))
        .findFirst()
        .map(RideGroup::getRoute)
        .map(route -> new GroupRoute(route.getId(), route.isDeleted()))
        .orElse(null);
  }

  /** Whether the TEAM mapping row of {@code biketeamTeamId} points at {@code teamId}. */
  @Transactional
  public boolean teamMappedTo(String biketeamTeamId, long teamId) {
    Long mapped = mapRepository.findTriblyId(BiketeamMigrationService.T_TEAM, biketeamTeamId);
    return mapped != null && mapped == teamId;
  }

  /** A team's ROUTE tag, as the migration made it. */
  public record TagView(String label, String color) {}

  /** The team's ROUTE tags, by label (docs/LEDGER_*.md MIG-14). */
  @Transactional
  public List<TagView> routeTags(long teamId) {
    return em.createQuery(
            "select t from Tag t where t.team.id = :t and t.type = :type order by lower(t.label)",
            fr.pedalons.domain.tag.Tag.class)
        .setParameter("t", teamId)
        .setParameter("type", fr.pedalons.enums.TagTarget.ROUTE)
        .getResultStream()
        .map(t -> new TagView(t.getLabel(), t.getColor().name()))
        .toList();
  }

  /** The labels of the tags a live route carries, by label — a doubled link shows twice. */
  @Transactional
  public List<String> routeTagLabels(long teamId, String routeName) {
    return em.createQuery(
            "select l.tag.label from TeamEntityTag l, Route r where l.teamEntity.id = r.id"
                + " and r.team.id = :t and r.name = :n and r.deleted = false"
                + " order by lower(l.tag.label)",
            String.class)
        .setParameter("t", teamId)
        .setParameter("n", routeName)
        .getResultList();
  }
}

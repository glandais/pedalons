package fr.pedalons.service.common;

import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.CountResponse;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.posts.response.PostAuthors;
import fr.pedalons.dto.publications.response.PublicationDto;
import fr.pedalons.dto.publications.response.PublicationListResponse;
import fr.pedalons.dto.publications.response.PublicationListSummaries;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.dto.publications.response.UserParticipations;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.PublicationWhen;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TagTarget;
import fr.pedalons.repository.common.AllPublicationRepository;
import fr.pedalons.repository.common.PublicationQuery;
import fr.pedalons.repository.ride.RideSummaryRepository;
import fr.pedalons.repository.trip.TripSummaryRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.asset.ThumbnailLookup;
import fr.pedalons.service.asset.ThumbnailLookup.ThemedThumbnail;
import fr.pedalons.service.comment.CommentCountLookup;
import fr.pedalons.service.post.PostAuthorLookup;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import fr.pedalons.service.team.TeamService;
import fr.pedalons.service.team.request.MinRole;
import fr.pedalons.service.weather.RideWeatherLookup;
import fr.pedalons.service.weather.RideWeatherSummaries;
import fr.pedalons.service.weather.TripWeatherLookup;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.UnaryOperator;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class PublicationService {

  @Inject AllPublicationRepository allPublicationRepository;

  @Inject AssetService assetService;

  @Inject PedalonsQueryContext pedalonsQueryContext;

  @Inject TeamService teamService;

  @Inject IncludeDeletedService includeDeletedService;

  @Inject RideSummaryRepository rideSummaryRepository;

  @Inject TripSummaryRepository tripSummaryRepository;

  @Inject ParticipationLookup participationLookup;

  @Inject CommentCountLookup commentCountLookup;

  @Inject PostAuthorLookup postAuthorLookup;

  @Inject MemberNamesVisibility memberNamesVisibility;

  @Inject TagLookup tagLookup;

  @Inject RideWeatherLookup rideWeatherLookup;
  @Inject TripWeatherLookup tripWeatherLookup;

  @Inject ThumbnailLookup thumbnailLookup;

  @Inject TagService tagService;

  /** Without the "me" filters — kept so existing callers do not have to pass two nulls. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      int page,
      int size) {
    return listAll(type, search, from, to, minRole, null, false, page, size);
  }

  /** Without the "me" filters — kept so existing callers do not have to pass two nulls. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public PublicationListResponse listTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      int page,
      int size) {
    return listTeam(teamSlug, type, search, from, to, null, false, page, size);
  }

  protected PublicationListResponse list(
      @Nullable PublicationType type,
      @Nullable Set<Long> teamIds,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      int page,
      int size,
      boolean includeDeleted,
      boolean platformAdmin) {
    return list(
        baseQuery(page, size)
            .type(type)
            .teamIds(teamIds)
            .search(search)
            .from(from)
            .to(to)
            .minRole(minRole)
            .includeDeleted(includeDeleted)
            .platformAdmin(platformAdmin)
            .build());
  }

  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      @Nullable Status status,
      boolean participating,
      int page,
      int size) {
    return listAll(
        type, search, from, to, minRole, status, participating, ListViewMode.FULL, page, size);
  }

  /**
   * @param view {@link ListViewMode#COMPACT} strips the markdown body and the asset inventory from every
   *     row; the rows are otherwise identical, and the query is exactly the same
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      @Nullable Status status,
      boolean participating,
      @Nullable ListViewMode view,
      int page,
      int size) {
    return listAll(type, search, from, to, minRole, status, participating, view, null, page, size);
  }

  /**
   * @param sortDir order of {@code dateTime}. {@code null} or {@link SortDirection#DESC} is the
   *     feed's newest-first; {@link SortDirection#ASC} is soonest-first, what a window of upcoming
   *     outings needs: with more outings in the window than {@code size}, a descending page would
   *     keep the furthest and drop the nearest.
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      @Nullable Status status,
      boolean participating,
      @Nullable ListViewMode view,
      @Nullable SortDirection sortDir,
      int page,
      int size) {
    return listAll(
        type, search, from, to, minRole, status, participating, view, null, sortDir, page, size);
  }

  /**
   * @param when {@link PublicationWhen#UPCOMING}: the rides and trips not over yet, soonest first;
   *     {@link PublicationWhen#PAST}: those over, latest first; null: no such filter. Judged by the
   *     end, not the start (docs/LEDGER_*.md API-85). Posts are never in either.
   * @param sortDir order of {@code dateTime}; given, it overrides the order {@code when} sets
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      @Nullable Status status,
      boolean participating,
      @Nullable ListViewMode view,
      @Nullable PublicationWhen when,
      @Nullable SortDirection sortDir,
      int page,
      int size) {
    return list(
        withWhen(
                baseQuery(page, size)
                    .type(type)
                    .search(search)
                    .from(from)
                    .to(to)
                    .minRole(minRole)
                    .status(status)
                    .participating(participating)
                    .includeDeleted(false),
                when,
                sortDir)
            .build(),
        view);
  }

  /**
   * What {@code when} stands for: the bound on the end, at the time of the request, and the order —
   * soonest departure first for what is ahead, latest first for what is over. An explicit {@code
   * sortDir} wins over that order.
   */
  static PublicationQuery.PublicationQueryBuilder withWhen(
      PublicationQuery.PublicationQueryBuilder query,
      @Nullable PublicationWhen when,
      @Nullable SortDirection sortDir) {
    Instant now = Instant.now();
    if (when == PublicationWhen.UPCOMING) {
      query.notEndedAt(now);
    } else if (when == PublicationWhen.PAST) {
      query.endedBefore(now);
    }
    boolean ascending =
        sortDir != null ? sortDir == SortDirection.ASC : when == PublicationWhen.UPCOMING;
    return query.ascending(ascending);
  }

  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public PublicationListResponse listTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      int page,
      int size) {
    return listTeam(
        teamSlug, type, search, from, to, status, participating, ListViewMode.FULL, page, size);
  }

  /**
   * @param view {@link ListViewMode#COMPACT} strips the markdown body and the asset inventory from every
   *     row; the rows are otherwise identical, and the query is exactly the same
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public PublicationListResponse listTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable ListViewMode view,
      int page,
      int size) {
    return listTeam(
        teamSlug, type, search, from, to, status, participating, null, view, page, size);
  }

  /**
   * @param tags the {@code ?tags=} filter of a team's dedicated list (plan D6, D18): ids of the
   *     team's tags of kind {@code type}, comma-separated or repeated. Honoured only with a {@code
   *     type} — the rides, the posts or the trips of the team; the mixed feed has no tag filter
   *     (plan D13) and ignores it. Unknown ids are ignored, and a filter left with none is no
   *     filter.
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public PublicationListResponse listTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable List<String> tags,
      @Nullable ListViewMode view,
      int page,
      int size) {
    return listTeam(
        teamSlug,
        type,
        search,
        from,
        to,
        status,
        participating,
        tags,
        view,
        null,
        false,
        false,
        page,
        size);
  }

  /**
   * @param sortDir order of {@code dateTime}, as on {@link #listAll}: {@code null} or {@link
   *     SortDirection#DESC} is newest first, {@link SortDirection#ASC} soonest first
   * @param withoutRoute only the rides routed nowhere — neither the ride nor any of its groups has a
   *     route
   * @param withFullGroup only the rides with at least one group at capacity
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public PublicationListResponse listTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable List<String> tags,
      @Nullable ListViewMode view,
      @Nullable SortDirection sortDir,
      boolean withoutRoute,
      boolean withFullGroup,
      int page,
      int size) {
    return listTeam(
        teamSlug,
        type,
        search,
        from,
        to,
        status,
        participating,
        tags,
        view,
        null,
        sortDir,
        withoutRoute,
        withFullGroup,
        page,
        size);
  }

  /**
   * @param when as on {@link #listAll}: the rides and trips not over yet ({@link
   *     PublicationWhen#UPCOMING}, soonest first) or over ({@link PublicationWhen#PAST}, latest
   *     first); with {@code participating}, « Je participe »
   * @param sortDir given, overrides the order {@code when} sets
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public PublicationListResponse listTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable List<String> tags,
      @Nullable ListViewMode view,
      @Nullable PublicationWhen when,
      @Nullable SortDirection sortDir,
      boolean withoutRoute,
      boolean withFullGroup,
      int page,
      int size) {
    Team team = teamService.getTeam(teamSlug);
    boolean includeDeleted = includeDeletedService.isTeamEntityIncludeDeleted(team);
    return list(
        withWhen(
                baseQuery(page, size)
                    .type(type)
                    .teamIds(Set.of(team.getId()))
                    .search(search)
                    .from(from)
                    .to(to)
                    .status(status)
                    .tagIds(tagFilter(team, type, tags))
                    .participating(participating)
                    .withoutRoute(withoutRoute)
                    .withFullGroup(withFullGroup)
                    .includeDeleted(includeDeleted),
                when,
                sortDir)
            .build(),
        view);
  }

  /**
   * One section of a team's dashboard: a short page of the team's publications, compact rows,
   * deleted ones left out whatever the caller's role — unlike {@link #listTeam}, which shows an
   * administrator the deleted ones too.
   *
   * <p>No {@code @CheckAccess}: the dashboard has already established that the caller may read the
   * team (a visitor too, docs/LEDGER_*.md API-86), and the visibility rules of the query apply row
   * by row, a visitor's included. Same per-page lookups as
   * every list, so the cost of a section does not depend on its rows.
   *
   * @param filters narrows the base query (type, window, status, order…); domain, team, caller and
   *     paging are set here
   */
  public PublicationListResponse listTeamSection(
      Team team, int size, UnaryOperator<PublicationQuery.PublicationQueryBuilder> filters) {
    return list(
        filters
            .apply(baseQuery(0, size).teamIds(Set.of(team.getId())).includeDeleted(false))
            .build(),
        ListViewMode.COMPACT);
  }

  /** How many publications {@link #listAll} would list, without listing them. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public CountResponse countAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      @Nullable Status status,
      boolean participating) {
    return countAll(type, search, from, to, minRole, status, participating, null);
  }

  /** Same, with the {@code when} filter of {@link #listAll}. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public CountResponse countAll(
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable MinRole minRole,
      @Nullable Status status,
      boolean participating,
      @Nullable PublicationWhen when) {
    return count(
        withWhen(
                baseQuery(0, 0)
                    .type(type)
                    .search(search)
                    .from(from)
                    .to(to)
                    .minRole(minRole)
                    .status(status)
                    .participating(participating)
                    .includeDeleted(false),
                when,
                null)
            .build());
  }

  /** How many publications {@link #listTeam} would list, without listing them. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public CountResponse countTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating) {
    return countTeam(teamSlug, type, search, from, to, status, participating, null);
  }

  /** Same, with the {@code ?tags=} filter of {@link #listTeam}. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public CountResponse countTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable List<String> tags) {
    return countTeam(teamSlug, type, search, from, to, status, participating, tags, false, false);
  }

  /** Same, with the {@code withoutRoute} and {@code withFullGroup} filters of {@link #listTeam}. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public CountResponse countTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable List<String> tags,
      boolean withoutRoute,
      boolean withFullGroup) {
    return countTeam(
        teamSlug,
        type,
        search,
        from,
        to,
        status,
        participating,
        tags,
        withoutRoute,
        withFullGroup,
        null);
  }

  /** Same, with the {@code when} filter of {@link #listTeam}. */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST)
  public CountResponse countTeam(
      String teamSlug,
      @Nullable PublicationType type,
      @Nullable String search,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      boolean participating,
      @Nullable List<String> tags,
      boolean withoutRoute,
      boolean withFullGroup,
      @Nullable PublicationWhen when) {
    Team team = teamService.getTeam(teamSlug);
    boolean includeDeleted = includeDeletedService.isTeamEntityIncludeDeleted(team);
    return count(
        withWhen(
                baseQuery(0, 0)
                    .type(type)
                    .teamIds(Set.of(team.getId()))
                    .search(search)
                    .from(from)
                    .to(to)
                    .status(status)
                    .tagIds(tagFilter(team, type, tags))
                    .participating(participating)
                    .withoutRoute(withoutRoute)
                    .withFullGroup(withFullGroup)
                    .includeDeleted(includeDeleted),
                when,
                null)
            .build());
  }

  /**
   * The resolved {@code ?tags=} filter of a team list, or null. Without a type the list is the
   * mixed feed, which filters on no tag (plan D13): the parameter is then ignored, not an error.
   */
  private @Nullable Set<Long> tagFilter(
      Team team, @Nullable PublicationType type, @Nullable List<String> tags) {
    if (type == null || tags == null || tags.isEmpty()) {
      return null;
    }
    return tagService.resolveFilter(team, TagTarget.valueOf(type.name()), tags);
  }

  /**
   * The rides and trips the current user is registered to, soonest first.
   *
   * <p>Goes through the ordinary publication query rather than straight at {@code
   * RideParticipation}: the registration is only half the answer, the other half is whether the user
   * may still see the publication at all (domain, team visibility, status, disabled modules). A
   * direct query on the participation table would return outings from another domain or from a team
   * the user has since left.
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listMyParticipations(
      @Nullable Instant from, @Nullable Instant to, @Nullable Status status, int page, int size) {
    return listMyParticipations(from, to, status, ListViewMode.FULL, page, size);
  }

  /**
   * @param view {@link ListViewMode#COMPACT} strips the markdown body and the asset inventory from every
   *     row
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public PublicationListResponse listMyParticipations(
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable Status status,
      @Nullable ListViewMode view,
      int page,
      int size) {
    return list(
        baseQuery(page, size)
            .from(from)
            .to(to)
            .status(status)
            .participating(true)
            .ascending(true)
            .includeDeleted(false)
            .build(),
        view);
  }

  /**
   * How many rides and trips the current user is registered to between {@code from} and {@code
   * to}: the {@code total} of {@link #listMyParticipations} for the same bounds, in one count query.
   */
  @CheckAccess(entityType = EntityType.PUBLICATION, action = ActionType.LIST_ALL_TEAMS)
  public long countMyParticipations(@Nullable Instant from, @Nullable Instant to) {
    return count(
            baseQuery(0, 1)
                .from(from)
                .to(to)
                .participating(true)
                .ascending(true)
                .includeDeleted(false)
                .build())
        .total();
  }

  private PublicationQuery.PublicationQueryBuilder baseQuery(int page, int size) {
    return PublicationQuery.builder()
        .domainId(pedalonsQueryContext.getDomainId())
        .pinnedTeamId(pedalonsQueryContext.getPinnedTeamIdNullable())
        .userId(pedalonsQueryContext.getUserIdNullable())
        .page(page)
        .size(size)
        .platformAdmin(isPlatformAdmin());
  }

  protected PublicationListResponse list(PublicationQuery query) {
    return list(query, ListViewMode.FULL);
  }

  protected PublicationListResponse list(PublicationQuery query, @Nullable ListViewMode view) {
    if (query.participating() && query.userId() == null) {
      // An anonymous visitor participates in nothing; no need to ask the database.
      return new PublicationListResponse(List.of(), 0, query.page(), query.size());
    }
    PedalonsPage<Publication> publications = allPublicationRepository.find(query);
    // The rows whose team's member names the caller may see — at most one query for the page, none
    // for a visitor or a platform admin (docs/LEDGER_*.md API-144). A non-member is sent the
    // counts, never the names: no participants, no leader, no signed author.
    Set<Long> namedTeamIds =
        memberNamesVisibility.teamsWithNames(
            publications.items().stream()
                .map(p -> p.getTeam().getId())
                .collect(Collectors.toSet()));
    Set<Long> namedRideIds =
        itemsOfType(publications.items(), Ride.class).stream()
            .filter(r -> namedTeamIds.contains(r.getTeam().getId()))
            .map(Ride::getId)
            .collect(Collectors.toSet());
    PublicationListSummaries summaries = loadSummaries(publications.items(), namedRideIds);
    UserParticipations participations = loadParticipations(publications.items(), namedRideIds);
    // Two more queries for the whole page, none per row — and nothing at all for a visitor who is
    // not a member of any of the teams on it.
    CommentCounts commentCounts = commentCountLookup.forEntities(publications.items());
    // At most two more, for the authors of the posts on the page (docs/LEDGER_*.md API-6).
    PostAuthors postAuthors =
        postAuthorLookup.forPosts(itemsOfType(publications.items(), Post.class), namedTeamIds);
    // One more for the tags of every row (docs/LEDGER_*.md API-59), none for an empty page.
    ContentTags tags =
        tagLookup.forContents(publications.items().stream().map(Publication::getId).toList());
    // At most one more for the weather line of every ride on the page, none when no ride of the
    // page leaves within the forecast horizon. Read from the cache only, never the provider.
    RideWeatherSummaries rideWeather =
        rideWeatherLookup.forRides(itemsOfType(publications.items(), Ride.class));
    // At most one more for the trips: the line of each trip's next leg, none when no trip of the
    // page has a stage left to leave (docs/LEDGER_*.md API-82).
    RideWeatherSummaries tripWeather =
        tripWeatherLookup.forTrips(itemsOfType(publications.items(), Trip.class), summaries::trip);
    // One more for the thumbnail of every ride, its own else its route's (docs/LEDGER_*.md
    // API-80), none for a page without rides.
    Map<Long, ThemedThumbnail> rideThumbnails =
        thumbnailLookup.forRides(itemsOfType(publications.items(), Ride.class));
    // And one for the trips, their own else their route's (docs/LEDGER_*.md API-83), none for a
    // page without trips.
    Map<Long, ThemedThumbnail> tripThumbnails =
        thumbnailLookup.forTrips(itemsOfType(publications.items(), Trip.class));
    List<PublicationDto> dtos =
        publications.items().stream()
            .map(
                publication ->
                    PublicationDto.from(
                        publication,
                        assetService,
                        summaries,
                        participations,
                        commentCounts,
                        postAuthors,
                        tags,
                        rideWeather,
                        tripWeather,
                        rideThumbnails,
                        tripThumbnails,
                        view))
            .toList();
    return new PublicationListResponse(dtos, publications.total(), query.page(), query.size());
  }

  protected CountResponse count(PublicationQuery query) {
    if (query.participating() && query.userId() == null) {
      // Same short circuit as list(): an anonymous visitor participates in nothing.
      return new CountResponse(0);
    }
    return new CountResponse(allPublicationRepository.countMatching(query));
  }

  /**
   * Resolves the "me" fields ({@code registered}, {@code registeredGroupId}, {@code
   * registeredGroup}) for the whole page at once — a fixed number of queries, whatever the page
   * size. Anonymous callers cost nothing.
   */
  private UserParticipations loadParticipations(List<Publication> items, Set<Long> namedRideIds) {
    return participationLookup.forListPage(
        idsOfType(items, Ride.class), idsOfType(items, Trip.class), namedRideIds);
  }

  /**
   * Loads the association aggregates for a whole page in bulk.
   *
   * <p>Without this, every ride row would walk {@code groups -> participations -> user} and every
   * trip row would load its {@code stages} and {@code participations} in full, just to produce a
   * handful of counts. Batch fetching keeps the query count flat while doing it, which is exactly
   * what makes the cost easy to miss: the queries stay constant, the rows hydrated do not.
   *
   * <p>Only the ids actually present on the page are queried, and a type absent from the page costs
   * nothing — the repositories short-circuit on an empty id list.
   */
  private PublicationListSummaries loadSummaries(List<Publication> items, Set<Long> namedRideIds) {
    return new PublicationListSummaries(
        rideSummaryRepository.loadListSummaries(idsOfType(items, Ride.class), namedRideIds),
        tripSummaryRepository.loadListSummaries(idsOfType(items, Trip.class)));
  }

  private static List<Long> idsOfType(List<Publication> items, Class<? extends Publication> type) {
    return items.stream().filter(type::isInstance).map(Publication::getId).toList();
  }

  private static <T extends Publication> List<T> itemsOfType(
      List<Publication> items, Class<T> type) {
    return items.stream().filter(type::isInstance).map(type::cast).toList();
  }

  protected boolean isPlatformAdmin() {
    return pedalonsQueryContext.isPlatformAdmin();
  }
}

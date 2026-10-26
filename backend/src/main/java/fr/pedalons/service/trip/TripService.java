package fr.pedalons.service.trip;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripParticipation;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.dto.trips.response.TripParticipationDto;
import fr.pedalons.dto.users.response.ParticipantListResponse;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.dto.weather.response.TripWeatherAnswer;
import fr.pedalons.dto.weather.response.TripWeatherDto;
import fr.pedalons.dto.weather.response.WeatherAttributionDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamEntityType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.infrastructure.exception.*;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.trip.TripParticipationRepository;
import fr.pedalons.repository.trip.TripRepository;
import fr.pedalons.repository.trip.TripStageRepository;
import fr.pedalons.service.comment.CommentCountLookup;
import fr.pedalons.service.common.MemberNamesVisibility;
import fr.pedalons.service.common.ParticipantPreviewLookup;
import fr.pedalons.service.common.ParticipationLookup;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.notification.NotificationPublisher;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import fr.pedalons.service.thumbnail.ThumbnailService;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import fr.pedalons.service.weather.TripWeatherService;
import fr.pedalons.service.weather.WeatherEtag;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class TripService extends TeamEntityService<Trip, TripRepository, TripDto> {

  @Inject TripRepository tripRepository;

  @Inject EventTimezoneResolver eventTimezoneResolver;

  @Inject TripStageRepository tripStageRepository;

  @Inject TripParticipationRepository participationRepository;

  @Inject RouteService routeService;

  @Inject PlaceRepository placeRepository;

  @Inject ThumbnailService thumbnailService;

  @Inject ParticipationLookup participationLookup;

  @Inject ParticipantPreviewLookup participantPreviewLookup;

  @Inject MemberNamesVisibility memberNamesVisibility;

  @Inject CommentCountLookup commentCountLookup;

  @Inject NotificationPublisher notificationPublisher;

  @Inject TagService tagService;

  @Inject TagLookup tagLookup;

  @Inject TripWeatherService tripWeatherService;

  @Inject ObjectMapper objectMapper;

  @Inject PublicationEndCalculator publicationEndCalculator;

  @Override
  protected TripRepository getRepository() {
    return tripRepository;
  }

  @Override
  protected TripDto toDto(Trip entity) {
    // The trip's tags and those of its stages' routes, in one query: the stage cards show their
    // route's tags (docs/plans/archive/2026-10-01-tags.md D15).
    List<Long> taggedIds = new ArrayList<>();
    taggedIds.add(entity.getId());
    entity.getStages().stream()
        .filter(stage -> !stage.isDeleted() && stage.getRoute() != null)
        .forEach(stage -> taggedIds.add(stage.getRoute().getId()));
    List<TeamEntity> commented = new ArrayList<>();
    commented.add(entity);
    entity.getStages().stream().filter(stage -> !stage.isDeleted()).forEach(commented::add);
    // One query for a logged-in caller, none for the others: only a member of the team is told who
    // goes (docs/LEDGER_*.md API-144).
    boolean withNames = memberNamesVisibility.canSeeNames(entity.getTeam().getId());
    // One indexed lookup resolves the "registered" flag; anonymous callers cost nothing.
    return TripDto.from(
        entity,
        assetService,
        participationLookup.forTrip(entity.getId()),
        // The trip's count and each live stage's, in the same two queries (docs/LEDGER_*.md
        // API-11).
        commentCountLookup.forEntities(commented),
        participantPreviewLookup.forTrip(entity.getId(), withNames),
        tagLookup.forContents(taggedIds));
  }

  /**
   * One page of the people registered to a trip — the list the detail only previews
   * (docs/LEDGER_*.md API-12). Read like the trip itself, but only by a member of the team: names
   * are never sent to anyone else (docs/LEDGER_*.md API-144).
   */
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.READ)
  public ParticipantListResponse getParticipants(
      String teamSlug, String tripSlug, @Nullable String search, int page, int size) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);
    if (!memberNamesVisibility.canSeeNames(team.getId())) {
      throw new ForbiddenException();
    }
    PedalonsPage<User> participants =
        participationRepository.findParticipants(trip.getId(), search, page, size);
    return new ParticipantListResponse(
        participants.items().stream().map(PublicUserDto::from).toList(),
        participants.total(),
        page,
        BaseRepository.effectivePageSize(size));
  }

  @Override
  public Trip findBySlug(Team team, String entitySlug) {
    return super.findBySlug(team, entitySlug);
  }

  /**
   * A live stage, by its slug — unique within the team, like the trip's — read like its trip: a
   * stage of a draft, deleted or hidden trip is not found. What its comment thread hangs off
   * (docs/LEDGER_*.md API-11).
   */
  public TripStage findStageBySlug(Team team, String stageSlug) {
    TripStage stage =
        tripStageRepository
            .findBySlugAndTeam(stageSlug, team.getId())
            .orElseThrow(() -> new NotFoundException(EntityType.TRIP_STAGE, stageSlug));
    boolean readable =
        tripRepository
            .findByTeamAndId(
                pedalonsContext.getDomainId(),
                team.getId(),
                pedalonsContext.getUserIdNullable(),
                stage.getTrip().getId(),
                isIncludeDeleted(team),
                isPlatformAdmin())
            .isPresent();
    if (!readable) {
      throw new NotFoundException(EntityType.TRIP_STAGE, stageSlug);
    }
    return stage;
  }

  /**
   * The trip's weather, stage by stage, read from the cache only: never a call to the provider,
   * never a write — a web SSR may prefetch it like any read. Readable by whoever may read the trip;
   * always an answer once it is readable, its state in {@code status} (docs/LEDGER_*.md API-76).
   */
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.READ)
  public TripWeatherAnswer getWeather(String teamSlug, String tripSlug) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);
    TripWeatherDto body =
        TripWeatherDto.from(
            tripWeatherService.forTrip(trip),
            new WeatherAttributionDto(
                OpenMeteoGateway.ATTRIBUTION_NAME, OpenMeteoGateway.ATTRIBUTION_URL));
    return new TripWeatherAnswer(
        body,
        body.status() == WeatherStatus.UNAVAILABLE ? null : WeatherEtag.of(objectMapper, body));
  }

  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.READ)
  public TripDto getDto(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.getDto(team, entitySlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.CREATE)
  public TripDto createTrip(String teamSlug, TripRequest request) {
    Team team = teamService.getTeam(teamSlug);
    User creator = pedalonsContext.getUser();
    validateVisibility(team, request);

    Visibility visibility = request.visibility();

    // Generate slug from name, ensure unique within team
    String slug = slugService.generateSlug(request.name(), team.getId(), tripRepository);

    Route route = getRoute(teamSlug, request.routeSlug(), visibility);
    // Every stage's zone before the trip's: the trip takes its first stage's, and a stage the
    // previous one's (docs/LEDGER_*.md API-60).
    List<StageParts> parts = stageParts(teamSlug, team, visibility, request.stages(), route);
    ZoneId zone = tripZone(team, parts, route);

    Trip trip =
        new Trip(
            creator, team, request.dateTime().toInstant(zone), request.name(), slug, visibility);
    trip.setTimezone(zone.getId());
    trip.setRoute(route);
    trip.setStatus(request.status());
    if (request.status() == Status.DRAFT) {
      trip.setPublishAt(EventDateTime.toInstant(request.publishAt(), zone));
    } else {
      trip.setPublishAt(null);
    }

    tripRepository.persistAndFlush(trip);

    updateMedia(trip, request.media());
    tripRepository.persist(trip);

    int sortOrder = 0;
    for (StageRequest stageRequest : request.stages()) {
      createTripStage(creator, trip, stageRequest, parts.get(sortOrder), sortOrder);
      sortOrder++;
    }
    // After the stages: the trip ends with the latest of them (docs/LEDGER_*.md API-85).
    publicationEndCalculator.refresh(trip);
    tagService.replaceTags(trip, request.tagIds());

    thumbnailService.generateTripThumbnails(trip);
    notificationPublisher.publicationStatusChanged(trip, null, creator);

    return toDto(trip);
  }

  private void createTripStage(
      User user, Trip trip, StageRequest stageRequest, StageParts parts, int sortOrder) {
    TripStage stage = new TripStage(user, trip, stageRequest.name(), stageSlug(trip, stageRequest));
    setStageProperties(trip, stage, stageRequest, parts, sortOrder);
    trip.addStage(stage);
    tripStageRepository.persistAndFlush(stage);
    updateMedia(stage, stageRequest.media());
    tripStageRepository.persist(stage);
  }

  /**
   * {@code TripStageRepository} is a plain {@code BaseRepository}, so the {@code
   * generateSlug(name, teamId, repository)} overload is out of reach — the uniqueness probe is spelt
   * out instead, via the {@code TeamEntityType}-aware overload so a reserved slug (should {@code
   * TRIP_STAGE} ever gain one in {@code SlugService.RESERVED_SLUGS}) is rejected the same way a
   * taken one is. It counts soft-deleted stages too, matching {@code uk_team_entity_slug}, which has
   * no {@code deleted} predicate. Panache adds the discriminator, so only stages are considered.
   */
  private String stageSlug(Trip trip, StageRequest stageRequest) {
    Long teamId = trip.getTeam().getId();
    String slug =
        slugService.generateSlug(
            stageRequest.name(),
            TeamEntityType.TRIP_STAGE,
            candidate ->
                tripStageRepository.count("team.id = ?1 and slug = ?2", teamId, candidate) > 0);
    slugService.clearEntityRedirect(teamId, TeamEntityType.TRIP_STAGE, slug);
    return slug;
  }

  /**
   * A stage's route and places, looked up before anything is written, and the zone they give it.
   */
  private record StageParts(
      @Nullable Route route, @Nullable Place start, @Nullable Place end, ZoneId zone) {}

  /** The parts of every stage of the request, in its order (docs/LEDGER_*.md API-60). */
  private List<StageParts> stageParts(
      String teamSlug,
      Team team,
      Visibility visibility,
      List<StageRequest> stages,
      @Nullable Route tripRoute) {
    List<Route> routes = new ArrayList<>();
    List<Place> starts = new ArrayList<>();
    List<Place> ends = new ArrayList<>();
    List<EventTimezoneResolver.StagePoints> points = new ArrayList<>();
    for (StageRequest stageRequest : stages) {
      Route stageRoute = getRoute(teamSlug, stageRequest.routeSlug(), visibility);
      Place startPlace = getPlace(stageRequest.startPlaceId(), team);
      routes.add(stageRoute);
      starts.add(startPlace);
      ends.add(getPlace(stageRequest.endPlaceId(), team));
      points.add(new EventTimezoneResolver.StagePoints(startPlace, stageRoute));
    }
    List<Optional<ZoneId>> zones = eventTimezoneResolver.locateStages(points, tripRoute);
    ZoneId teamZone = EventTimezoneResolver.teamZone(team);
    List<StageParts> parts = new ArrayList<>();
    for (int i = 0; i < stages.size(); i++) {
      parts.add(
          new StageParts(routes.get(i), starts.get(i), ends.get(i), zones.get(i).orElse(teamZone)));
    }
    return parts;
  }

  /** The trip's zone: its first stage's, else its route's, else the team's. */
  private ZoneId tripZone(Team team, List<StageParts> parts, @Nullable Route tripRoute) {
    if (!parts.isEmpty()) {
      // The first stage's chain already ends with the trip route, then the team.
      return parts.getFirst().zone();
    }
    return eventTimezoneResolver
        .locateTrip(List.of(), tripRoute)
        .orElse(EventTimezoneResolver.teamZone(team));
  }

  private void setStageProperties(
      Trip trip, TripStage stage, StageRequest stageRequest, StageParts parts, int sortOrder) {
    stage.setTrip(trip);
    stage.setName(stageRequest.name());
    stage.setTimezone(parts.zone().getId());
    stage.setDateTime(stageRequest.dateTime().toInstant(parts.zone()));
    stage.setAverageSpeed(stageRequest.averageSpeed());
    stage.setRoute(parts.route());
    stage.setStartPlace(parts.start());
    stage.setEndPlace(parts.end());
    stage.setSortOrder(sortOrder);
    // Inherit visibility from trip
    stage.setVisibility(trip.getVisibility());
    stage.setStatus(trip.getStatus());
  }

  private @Nullable Route getRoute(
      String teamSlug, @Nullable String routeSlug, Visibility visibility) {
    Route route = null;
    if (routeSlug != null) {
      route = routeService.get(teamSlug, routeSlug);
      if (visibility != Visibility.TEAM && route.getVisibility() == Visibility.TEAM) {
        throw new BusinessException(ErrorCode.PUBLIC_TRIP_PRIVATE_ROUTE);
      }
    }
    return route;
  }

  private @Nullable Place getPlace(@Nullable String placeId, Team team) {
    if (placeId == null) {
      return null;
    }
    Long id = TsidUtils.toLong(placeId);
    return placeRepository
        .findByIdAndTeam(id, team.getId())
        .orElseThrow(() -> new NotFoundException(EntityType.PLACE, placeId));
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.UPDATE)
  public TripDto updateTrip(String teamSlug, String tripSlug, TripRequest request) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);
    User user = pedalonsContext.getUser();
    Status previousStatus = trip.getStatus();
    List<List<Long>> previousThumbnailInput = ThumbnailService.tripInput(trip);

    // Validate visibility: private teams can only have team-only trips
    validateVisibility(team, request);
    trip.setVisibility(request.visibility());

    trip.setName(request.name());
    trip.setStatus(request.status());
    Route route = getRoute(teamSlug, request.routeSlug(), trip.getVisibility());
    trip.setRoute(route);
    // Every stage's zone before the trip's dates (docs/LEDGER_*.md API-60).
    List<StageParts> parts =
        stageParts(teamSlug, team, trip.getVisibility(), request.stages(), route);
    ZoneId zone = tripZone(team, parts, route);
    trip.setTimezone(zone.getId());
    trip.setDateTime(request.dateTime().toInstant(zone));
    if (request.status() == Status.DRAFT) {
      trip.setPublishAt(EventDateTime.toInstant(request.publishAt(), zone));
    } else {
      trip.setPublishAt(null);
    }

    updateMedia(trip, request.media());

    Map<Long, TripStage> existingStages =
        trip.getStages().stream().collect(Collectors.toMap(TripStage::getId, Function.identity()));
    for (TripStage stage : trip.getStages()) {
      stage.setDeleted(true);
      stage.setSortOrder(0);
    }
    int sortOrder = 0;
    for (StageRequest stageRequest : request.stages()) {
      Long stageId = TsidUtils.toLongNullable(stageRequest.id());
      if (stageId == null) {
        createTripStage(user, trip, stageRequest, parts.get(sortOrder), sortOrder);
      } else {
        TripStage existingStage = existingStages.remove(stageId);
        if (existingStage != null) {
          existingStage.setDeleted(false);
          setStageProperties(trip, existingStage, stageRequest, parts.get(sortOrder), sortOrder);
          updateMedia(existingStage, stageRequest.media());
          // No persist needed - entity is already managed and will be updated on flush
        } else {
          throw new NotFoundException(EntityType.TRIP_STAGE, stageRequest.id());
        }
      }
      sortOrder++;
    }
    // Stages created, edited, dropped or reordered: all go through here (API-85).
    publicationEndCalculator.refresh(trip);
    tagService.replaceTags(trip, request.tagIds());

    tripRepository.persist(trip);

    thumbnailService.refreshTripThumbnails(trip, previousThumbnailInput);
    notificationPublisher.publicationStatusChanged(trip, previousStatus, user);

    return toDto(trip);
  }

  /**
   * Changes the status alone. The stages follow, as {@link #setStageProperties} makes them do on a
   * full update: the calendar and its ICS feeds read a stage's own status.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.UPDATE)
  public TripDto updateStatus(String teamSlug, String tripSlug, Status status) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);
    Status previousStatus = trip.getStatus();
    trip.setStatus(status);
    if (status != Status.DRAFT) {
      trip.setPublishAt(null);
    }
    for (TripStage stage : trip.getStages()) {
      stage.setStatus(status);
    }
    tripRepository.persist(trip);
    notificationPublisher.publicationStatusChanged(trip, previousStatus, pedalonsContext.getUser());
    return toDto(trip);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.UPDATE)
  public TripDto updateSlug(String teamSlug, String slug, String newSlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.updateSlug(team, slug, newSlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.DELETE)
  public void deleteTrip(String teamSlug, String tripSlug) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);

    trip.setDeleted(true);
    tripRepository.persist(trip);
  }

  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.DELETE)
  @Transactional
  public TripDto undeleteTrip(String teamSlug, String tripSlug) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlugIncludeDeleted(team, tripSlug);
    requireNotRemovedByModeration(trip);
    trip.setDeleted(false);
    tripRepository.persist(trip);
    return toDto(trip);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.JOIN)
  public TripParticipationDto joinTrip(String teamSlug, String tripSlug) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);
    User user = pedalonsContext.getUser();

    Optional<TripParticipation> existingParticipation =
        participationRepository.findByUserAndTrip(user.getId(), trip.getId());

    if (existingParticipation.isPresent()) {
      throw new ConflictException(ErrorCode.ALREADY_REGISTERED);
    }

    TripParticipation participation = new TripParticipation(trip, user);

    trip.addParticipation(participation);
    participationRepository.persist(participation);

    return TripParticipationDto.from(participation);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.LEAVE)
  public void leaveTrip(String teamSlug, String tripSlug) {
    Team team = teamService.getTeam(teamSlug);
    Trip trip = findBySlug(team, tripSlug);

    TripParticipation participation =
        participationRepository
            .findByUserAndTrip(pedalonsContext.getUserId(), trip.getId())
            .orElseThrow(() -> new BusinessException(ErrorCode.NOT_REGISTERED));

    participationRepository.delete(participation);
  }
}

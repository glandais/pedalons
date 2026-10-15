package fr.pedalons.service.ride;

import static fr.pedalons.dto.error.ErrorCode.ALREADY_REGISTERED;
import static fr.pedalons.dto.error.ErrorCode.NOT_REGISTERED;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.rides.response.*;
import fr.pedalons.dto.users.response.ParticipantListResponse;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.dto.weather.response.RideWeatherAnswer;
import fr.pedalons.dto.weather.response.RideWeatherDto;
import fr.pedalons.dto.weather.response.WeatherAttributionDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideGroupRepository;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.ridetemplate.RideTemplateRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.asset.ThumbnailLookup;
import fr.pedalons.service.comment.CommentCountLookup;
import fr.pedalons.service.common.ParticipantPreviewLookup;
import fr.pedalons.service.common.ParticipationLookup;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.notification.NotificationPublisher;
import fr.pedalons.service.notification.event.RideGroupRemoved;
import fr.pedalons.service.notification.event.RideJoined;
import fr.pedalons.service.notification.event.RideUpdated;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import fr.pedalons.service.thumbnail.ThumbnailService;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import fr.pedalons.service.weather.RideWeatherLookup;
import fr.pedalons.service.weather.RideWeatherService;
import fr.pedalons.service.weather.WeatherEtag;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RideService extends TeamEntityService<Ride, RideRepository, RideDto> {

  @Inject RideRepository rideRepository;

  @Inject RideGroupRepository rideGroupRepository;

  @Inject RideParticipationRepository participationRepository;

  @Inject RouteService routeService;

  @Inject PlaceRepository placeRepository;

  @Inject RideTemplateRepository rideTemplateRepository;

  @Inject ThumbnailService thumbnailService;

  @Inject ParticipationLookup participationLookup;

  @Inject CommentCountLookup commentCountLookup;

  @Inject ThumbnailLookup thumbnailLookup;

  @Inject ParticipantPreviewLookup participantPreviewLookup;

  @Inject UserTeamRepository userTeamRepository;

  @Inject NotificationPublisher notificationPublisher;

  @Inject TagService tagService;

  @Inject TagLookup tagLookup;

  @Inject RideWeatherLookup rideWeatherLookup;

  @Inject RideWeatherService rideWeatherService;

  @Inject ObjectMapper objectMapper;

  @Inject PublicationEndCalculator publicationEndCalculator;

  @Inject EventTimezoneResolver eventTimezoneResolver;

  /** How long a ride edit waits before notifying — the window in which further edits fold in. */
  @ConfigProperty(name = "pedalons.notifications.update-delay-seconds", defaultValue = "300")
  int updateDelaySeconds;

  @Override
  protected RideRepository getRepository() {
    return rideRepository;
  }

  @Override
  protected RideDto toDto(Ride entity) {
    // One indexed lookup resolves registered/registeredGroupId for the ride and all of its groups,
    // and one query the thumbnails of every group route — never route.getAssets() per group.
    List<Long> groupRouteIds =
        entity.getGroups().stream()
            .map(RideGroup::getRoute)
            .filter(Objects::nonNull)
            .map(Route::getId)
            .toList();
    return RideDto.from(
        entity,
        assetService,
        participationLookup.forRide(entity.getId()),
        commentCountLookup.forEntity(entity),
        thumbnailLookup.forTeamEntities(groupRouteIds),
        participantPreviewLookup.forRideGroups(
            entity.getGroups().stream().map(RideGroup::getId).toList()),
        tagLookup.forContent(entity.getId()),
        // The same card line as the lists, so a ride reads alike in both; none for a ride outside
        // the forecast window, at most one query otherwise.
        rideWeatherLookup.forRides(List.of(entity)));
  }

  /**
   * The ride's weather for its detail page, read from the cache only: never a call to the
   * provider, never a write — a web SSR may prefetch it like any read. Readable by whoever may read
   * the ride; always an answer once it is readable, its state in {@code status}.
   */
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.READ)
  public RideWeatherAnswer getWeather(String teamSlug, String rideSlug) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);
    RideWeatherDto body =
        RideWeatherDto.from(
            rideWeatherService.forRide(ride),
            new WeatherAttributionDto(
                OpenMeteoGateway.ATTRIBUTION_NAME, OpenMeteoGateway.ATTRIBUTION_URL));
    return new RideWeatherAnswer(
        body,
        body.status() == WeatherStatus.UNAVAILABLE ? null : WeatherEtag.of(objectMapper, body));
  }

  /**
   * One page of the people registered to a ride, or to one of its groups — the list the detail
   * only previews (docs/LEDGER_*.md API-12). Read like the ride itself: whoever may read the ride
   * may read who rides it.
   *
   * @param groupId {@code null} for the whole ride; a group of another ride is a 404
   */
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.READ)
  public ParticipantListResponse getParticipants(
      String teamSlug,
      String rideSlug,
      @Nullable Long groupId,
      @Nullable String search,
      int page,
      int size) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);
    if (groupId != null && rideGroupRepository.findByIdAndRide(groupId, ride.getId()).isEmpty()) {
      throw new NotFoundException(EntityType.RIDE_GROUP, groupId);
    }
    PedalonsPage<User> participants =
        participationRepository.findParticipants(ride.getId(), groupId, search, page, size);
    return new ParticipantListResponse(
        participants.items().stream().map(PublicUserDto::from).toList(),
        participants.total(),
        page,
        BaseRepository.effectivePageSize(size));
  }

  @Override
  public Ride findBySlug(Team team, String entitySlug) {
    return super.findBySlug(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.READ)
  public RideDto getDto(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.getDto(team, entitySlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.CREATE)
  public RideDto createRide(String teamSlug, RideRequest request) {
    Team team = teamService.getTeam(teamSlug);
    User creator = pedalonsContext.getUser();
    validateVisibility(team, request);

    // Generate slug from name, ensure unique within team
    String slug = slugService.generateSlug(request.name(), team.getId(), rideRepository);

    Route route = getRoute(teamSlug, request.routeSlug(), request.visibility());
    Place startPlace = getPlace(request.startPlaceId(), team);
    Place endPlace = getPlace(request.endPlaceId(), team);

    // The zone first: the request's wall times are read in it (docs/LEDGER_*.md API-60).
    ZoneId zone = eventTimezoneResolver.ride(team, startPlace, route);
    Ride ride =
        new Ride(
            creator,
            team,
            request.dateTime().toInstant(zone),
            request.name(),
            slug,
            request.visibility());
    ride.setTimezone(zone.getId());
    ride.setRoute(route);
    ride.setStart(startPlace);
    ride.setEnd(endPlace);
    ride.setStatus(request.status());
    if (request.status() == Status.DRAFT) {
      ride.setPublishAt(EventDateTime.toInstant(request.publishAt(), zone));
    } else {
      ride.setPublishAt(null);
    }
    rideRepository.persistAndFlush(ride);

    updateMedia(ride, request.media());
    rideRepository.persist(ride);

    int sortOrder = 0;
    for (GroupRequest groupRequest : request.groups()) {
      createRideGroup(teamSlug, creator, ride, groupRequest, sortOrder, zone);
      sortOrder++;
    }
    // After the groups: the end is the latest of them (docs/LEDGER_*.md API-85).
    publicationEndCalculator.refresh(ride);
    // A ride created from a template arrives with the template's tags in tagIds: the client
    // prefilled the form from RideTemplateDto.tags (docs/plans/archive/2026-10-01-tags.md D14).
    tagService.replaceTags(ride, request.tagIds());
    // The client titled the ride « name #n » from RideTemplateDto.nextNumber: the next one takes
    // n + 1, whatever name was finally kept, as biketeam did (docs/LEDGER_*.md API-108).
    if (request.templateId() != null) {
      rideTemplateRepository.raiseNextNumber(team.getId(), TsidUtils.toLong(request.templateId()));
    }

    thumbnailService.generateRideThumbnails(ride);
    notificationPublisher.publicationStatusChanged(ride, null, creator);

    return toDto(ride);
  }

  private void createRideGroup(
      String teamSlug,
      User user,
      Ride ride,
      GroupRequest groupRequest,
      int sortOrder,
      ZoneId zone) {
    RideGroup group = new RideGroup(user, ride, groupRequest.name());
    setProperties(teamSlug, ride, group, groupRequest, sortOrder, user, zone, 0);
    ride.addGroup(group);
    rideGroupRepository.persist(group);
  }

  private void setProperties(
      String teamSlug,
      Ride ride,
      RideGroup group,
      GroupRequest groupRequest,
      int sortOrder,
      User user,
      ZoneId zone,
      long dayOffset) {
    group.setRide(ride);
    group.setName(groupRequest.name());
    // The ride's date and zone are final by now: its groups leave on its local date, in its zone —
    // shifted by the day offset an existing group already had (docs/LEDGER_*.md API-101).
    EventTimezoneResolver.setStart(group, ride.getDateTime(), groupRequest.time(), zone, dayOffset);
    Route groupRoute = getRoute(teamSlug, groupRequest.routeSlug(), ride.getVisibility());
    group.setAverageSpeed(groupRequest.averageSpeed());
    group.setMaxParticipants(groupRequest.maxParticipants());
    group.setSortOrder(sortOrder);
    group.setRoute(groupRoute);
    group.setLeader(resolveLeader(ride, group.getLeader(), groupRequest.leaderId()));
  }

  /**
   * The member designated to lead a group, or null.
   *
   * <p>Membership of the ride's team is checked rather than assumed. Without it, any user id in the
   * domain could be written into a group and rendered as its leader on a page every member reads —
   * a way to attribute a ride to someone who never agreed to lead it. Requiring participation
   * instead would be worse: groups are built before anyone has signed up.
   *
   * <p>The check is deliberately not re-run afterwards. A leader who later leaves the team keeps
   * the row: the group happened, and rewriting history on a membership change would silently
   * unattribute past rides. The read path renders whoever is there. Clients send the whole ride
   * back on every save — publishing, cancelling, a typo fix — so a leader the group already has is
   * kept as is: checking them again would lock the ride until someone cleared the leader.
   */
  private @Nullable User resolveLeader(
      Ride ride, @Nullable User currentLeader, @Nullable String leaderId) {
    Long id = TsidUtils.toLongNullable(leaderId);
    if (id == null) {
      return null;
    }
    if (currentLeader != null && id.equals(currentLeader.getId())) {
      return currentLeader;
    }
    Long teamId = ride.getTeam().getId();
    return userTeamRepository
        .findByUserAndTeam(id, teamId)
        .map(UserTeam::getUser)
        .orElseThrow(() -> new BusinessException(ErrorCode.RIDE_GROUP_LEADER_NOT_MEMBER));
  }

  private @Nullable Route getRoute(
      String teamSlug, @Nullable String routeSlug, Visibility visibility) {
    Route route = null;
    if (routeSlug != null) {
      route = routeService.get(teamSlug, routeSlug);
      if (visibility != Visibility.TEAM && route.getVisibility() == Visibility.TEAM) {
        throw new BusinessException(ErrorCode.PUBLIC_RIDE_PRIVATE_ROUTE);
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
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.UPDATE)
  public RideDto updateRide(String teamSlug, String rideSlug, RideRequest request) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);
    User user = pedalonsContext.getUser();
    Status previousStatus = ride.getStatus();
    Instant previousDateTime = ride.getDateTime();
    ZoneId previousZone = ride.zone();
    Long previousStartPlaceId = ride.getStart() != null ? ride.getStart().getId() : null;
    List<List<Long>> previousThumbnailInput = ThumbnailService.rideInput(ride);

    validateVisibility(team, request);
    ride.setVisibility(request.visibility());

    ride.setName(request.name());
    ride.setStatus(request.status());
    Route route = getRoute(teamSlug, request.routeSlug(), request.visibility());
    ride.setRoute(route);
    Place startPlace = getPlace(request.startPlaceId(), team);
    Place endPlace = getPlace(request.endPlaceId(), team);
    ride.setStart(startPlace);
    ride.setEnd(endPlace);
    // Once the place and the route are known: a new start place keeps the wall time and moves the
    // instant (plan §2.5), which RideUpdated below then reports (docs/LEDGER_*.md API-60).
    ZoneId zone = eventTimezoneResolver.ride(team, startPlace, route);
    ride.setTimezone(zone.getId());
    ride.setDateTime(request.dateTime().toInstant(zone));
    if (request.status() == Status.DRAFT) {
      ride.setPublishAt(EventDateTime.toInstant(request.publishAt(), zone));
    } else {
      ride.setPublishAt(null);
    }
    updateMedia(ride, request.media());

    // Never empty a collection with orphanRemoval to refill it right after: setProperties looks a
    // route up, and any query makes Hibernate run its flush-time cascades — which would see the
    // emptied collection, declare every group an orphan and delete it. Putting them back afterwards
    // does not bring them back. So the groups stay in place and only the unclaimed ones leave,
    // once.
    Map<Long, RideGroup> orphanedGroups =
        ride.getGroups().stream().collect(Collectors.toMap(RideGroup::getId, Function.identity()));
    int sortOrder = 0;
    for (GroupRequest groupRequest : request.groups()) {
      Long groupId = TsidUtils.toLongNullable(groupRequest.id());
      if (groupId == null) {
        createRideGroup(teamSlug, user, ride, groupRequest, sortOrder, zone);
      } else {
        RideGroup existingRideGroup = orphanedGroups.remove(groupId);
        if (existingRideGroup == null) {
          throw new NotFoundException(EntityType.RIDE_GROUP, groupRequest.id());
        }
        // Read before the save, like the time the client sends back (docs/LEDGER_*.md API-101).
        long dayOffset =
            EventTimezoneResolver.dayOffset(
                previousDateTime, existingRideGroup.getStartAt(), previousZone);
        setProperties(
            teamSlug, ride, existingRideGroup, groupRequest, sortOrder, user, zone, dayOffset);
      }
      sortOrder++;
    }
    // The riders of a removed group lose their registration with it (orphanRemoval): each is told,
    // once the ride is published — a draft has nobody registered.
    if (ride.getStatus() == Status.PUBLISHED) {
      for (RideGroup removed : orphanedGroups.values()) {
        List<Long> riders =
            removed.getParticipations().stream().map(p -> p.getUser().getId()).toList();
        if (!riders.isEmpty()) {
          notificationPublisher.publish(
              new RideGroupRemoved(ride.getId(), removed.getId(), removed.getName(), riders),
              team,
              user);
        }
      }
    }
    ride.getGroups().removeAll(orphanedGroups.values());
    // Once the groups are final — departure, times, routes and speeds all count (API-85).
    publicationEndCalculator.refresh(ride);
    // Tags notify nobody (plan D23): RideUpdated below only looks at the date and the start place.
    tagService.replaceTags(ride, request.tagIds());

    rideRepository.persist(ride);

    thumbnailService.refreshRideThumbnails(ride, previousThumbnailInput);
    notificationPublisher.publicationStatusChanged(ride, previousStatus, user);
    // Only a ride that stays published has riders to warn; the resolver compares the state before
    // with the state after the delay, so an edit undone in the meantime notifies nobody.
    if (previousStatus == Status.PUBLISHED
        && ride.getStatus() == Status.PUBLISHED
        && (!previousDateTime.equals(ride.getDateTime())
            || !Objects.equals(
                previousStartPlaceId, startPlace != null ? startPlace.getId() : null))) {
      notificationPublisher.publish(
          new RideUpdated(ride.getId(), previousDateTime, previousStartPlaceId),
          team,
          user,
          Duration.ofSeconds(updateDelaySeconds));
    }

    return toDto(ride);
  }

  /**
   * Changes the status alone — groups, route and media stay as they are. Same side effects as a
   * status change through {@link #updateRide}: a scheduled publication is dropped unless the ride
   * goes back to draft, and the transition is announced through the notification outbox.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.UPDATE)
  public RideDto updateStatus(String teamSlug, String rideSlug, Status status) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);
    Status previousStatus = ride.getStatus();
    ride.setStatus(status);
    if (status != Status.DRAFT) {
      ride.setPublishAt(null);
    }
    rideRepository.persist(ride);
    notificationPublisher.publicationStatusChanged(ride, previousStatus, pedalonsContext.getUser());
    return toDto(ride);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.UPDATE)
  public RideDto updateSlug(String teamSlug, String slug, String newSlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.updateSlug(team, slug, newSlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.DELETE)
  public void deleteRide(String teamSlug, String rideSlug) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);

    ride.setDeleted(true);
    rideRepository.persist(ride);
  }

  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.DELETE)
  @Transactional
  public RideDto undeleteRide(String teamSlug, String rideSlug) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlugIncludeDeleted(team, rideSlug);
    requireNotRemovedByModeration(ride);
    ride.setDeleted(false);
    rideRepository.persist(ride);
    return toDto(ride);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.JOIN)
  public RideParticipationDto joinGroup(String teamSlug, String rideSlug, Long groupId) {
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);
    // Before the group is read and its participations loaded: concurrent joins of this ride queue
    // here, and each check below sees the joins committed before it (docs/LEDGER_*.md API-98,
    // API-99).
    rideRepository.lockForJoin(ride);
    // The access check read the status before the lock: a cancellation or unpublish committed in
    // between is only visible now.
    if (ride.getStatus() != Status.PUBLISHED) {
      throw new ForbiddenException();
    }

    RideGroup group =
        rideGroupRepository
            .findByIdAndRide(groupId, ride.getId())
            .orElseThrow(() -> new NotFoundException(EntityType.RIDE_GROUP, groupId));

    Optional<RideParticipation> existingParticipation =
        participationRepository.findByUserAndRide(pedalonsContext.getUserId(), ride.getId());

    if (existingParticipation.isPresent()) {
      throw new ConflictException(ALREADY_REGISTERED);
    }
    // The clients hide « Rejoindre » once the ride has started; the rule is here. Leaving stays
    // open, to correct who actually came.
    if (ride.getDateTime().isBefore(Instant.now())) {
      throw new ConflictException(ErrorCode.RIDE_PAST);
    }

    checkCapacity(group);

    RideParticipation participation = new RideParticipation(group, pedalonsContext.getUser());

    group.addParticipation(participation);
    participationRepository.persist(participation);
    notificationPublisher.publish(
        new RideJoined(participation.getId()), team, pedalonsContext.getUser());

    return RideParticipationDto.from(participation);
  }

  private void checkCapacity(RideGroup group) {
    if (!group.hasCapacity()) {
      throw new ConflictException(ErrorCode.GROUP_FULL);
    }
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.LEAVE)
  public void leaveGroup(String teamSlug, String rideSlug, Long groupId) {
    // The access check vouched for the ride of the URL only: the group must be one of its own, or a
    // published ride of a team the caller belongs to would unregister them from any other ride —
    // cancelled, draft, or of a team they left (docs/LEDGER_*.md SEC-38).
    Team team = teamService.getTeam(teamSlug);
    Ride ride = findBySlug(team, rideSlug);
    RideGroup group =
        rideGroupRepository
            .findByIdAndRide(groupId, ride.getId())
            .orElseThrow(() -> new NotFoundException(EntityType.RIDE_GROUP, groupId));

    RideParticipation participation =
        participationRepository
            .findByUserAndGroup(pedalonsContext.getUserId(), group.getId())
            .orElseThrow(() -> new BusinessException(NOT_REGISTERED));

    participationRepository.delete(participation);
  }
}

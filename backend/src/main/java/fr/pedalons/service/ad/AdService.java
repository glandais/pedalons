package fr.pedalons.service.ad;

import fr.pedalons.common.CoarseLocation;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.InternalException;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.ad.AdContact;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.ads.request.AdContactRequest;
import fr.pedalons.dto.ads.request.AdRequest;
import fr.pedalons.dto.ads.request.AdSearchParams;
import fr.pedalons.dto.ads.response.AdDto;
import fr.pedalons.dto.ads.response.AdEditDto;
import fr.pedalons.dto.ads.response.AdListResponse;
import fr.pedalons.dto.common.CountResponse;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.enums.*;
import fr.pedalons.repository.ad.AdContactRepository;
import fr.pedalons.repository.ad.AdQuery;
import fr.pedalons.repository.ad.AdRepository;
import fr.pedalons.service.common.ContentPermissions;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AdService extends TeamEntityService<Ad, AdRepository, AdDto> {

  @Inject AdRepository adRepository;

  @Inject AdContactRepository adContactRepository;

  @Inject AdContactEmailService adContactEmailService;

  @Inject TagService tagService;

  @Inject TagLookup tagLookup;

  /**
   * Tolerance when matching a submitted point against the blurred one served: ~1 cm, below the six
   * decimals {@link CoarseLocation} rounds to, so a JSON round trip never reads as a move.
   */
  private static final double SAME_POINT_DEGREES = 1e-7;

  @ConfigProperty(name = "pedalons.ads.contact.max-per-window", defaultValue = "10")
  int contactMaxPerWindow;

  @ConfigProperty(name = "pedalons.ads.contact.rate-limit-window-minutes", defaultValue = "60")
  int contactWindowMinutes;

  @Override
  protected AdRepository getRepository() {
    return adRepository;
  }

  @Override
  protected AdDto toDto(Ad entity) {
    return AdDto.from(
        entity,
        assetService,
        tagLookup.forContents(List.of(entity.getId())),
        detailPermissions(entity));
  }

  @Override
  protected Ad findBySlug(Team team, String entitySlug) {
    return super.findBySlug(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.AD, action = ActionType.READ)
  public AdDto getDto(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.getDto(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.AD, action = ActionType.UPDATE)
  public AdEditDto getDtoEdit(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    Ad entity = findBySlug(team, entitySlug);
    return toEditDto(entity);
  }

  @CheckAccess(entityType = EntityType.AD, action = ActionType.LIST)
  public AdListResponse listAds(
      String teamSlug,
      @Nullable String search,
      @Nullable AdType adType,
      @Nullable Instant from,
      @Nullable Instant to,
      int page,
      int size) {
    return listAds(teamSlug, search, adType, from, to, ListViewMode.FULL, page, size);
  }

  /**
   * @param view {@link ListViewMode#COMPACT} strips the description and the asset inventory from every
   *     row; the rows are otherwise identical, and the query is exactly the same
   */
  @CheckAccess(entityType = EntityType.AD, action = ActionType.LIST)
  public AdListResponse listAds(
      String teamSlug,
      @Nullable String search,
      @Nullable AdType adType,
      @Nullable Instant from,
      @Nullable Instant to,
      @Nullable ListViewMode view,
      int page,
      int size) {
    return listAds(
        teamSlug,
        AdSearchParams.builder().search(search).adType(adType).from(from).to(to).build(),
        view,
        page,
        size);
  }

  /**
   * The classifieds of a team, filtered and sorted.
   *
   * <p>The filters live in {@link AdSearchParams} rather than in the signature so that adding one
   * does not ripple through every caller — the route search learnt the same lesson at fifteen
   * parameters.
   */
  @CheckAccess(entityType = EntityType.AD, action = ActionType.LIST)
  public AdListResponse listAds(
      String teamSlug, AdSearchParams params, @Nullable ListViewMode view, int page, int size) {
    Team team = teamService.getTeam(teamSlug);
    Set<Long> tagIds = tagFilter(team, params);
    PedalonsPage<Ad> ads =
        adRepository.find(
            AdQuery.builder()
                .domainId(pedalonsContext.getDomainId())
                .userId(pedalonsContext.getUserIdNullable())
                .teamIds(Set.of(team.getId()))
                .search(params.search())
                .adType(params.adType())
                .from(params.from())
                .to(params.to())
                .minPrice(params.minPrice())
                .maxPrice(params.maxPrice())
                .nearLat(params.nearLat())
                .nearLon(params.nearLon())
                .nearRadius(params.nearRadius())
                .tagIds(tagIds)
                .sortBy(params.sortBy())
                .sortDir(params.sortDir())
                .page(page)
                .size(size)
                .platformAdmin(isPlatformAdmin())
                .build());
    // One query for the tags of the whole page, none for an empty one.
    ContentTags tags = tagLookup.forContents(ads.items().stream().map(Ad::getId).toList());
    // One more for the caller's role, the permissions block of every row (docs/LEDGER_*.md
    // API-176): every ad of the page is of this one team.
    ContentPermissions permissions =
        ContentPermissions.forList(callerRolesLookup.callerRoles(team.getId()));
    List<AdDto> dtos =
        ads.items().stream()
            .map(ad -> AdDto.from(ad, assetService, tags, permissions, view))
            .toList();
    return new AdListResponse(dtos, ads.total(), page, size);
  }

  /**
   * How many classifieds {@link #listAds(String, AdSearchParams, ListViewMode, int, int)} would
   * list, without listing them. Built from the same {@link AdQuery} as the listing, minus sorting
   * and pagination, so the two can never disagree.
   */
  @CheckAccess(entityType = EntityType.AD, action = ActionType.LIST)
  public CountResponse countAds(String teamSlug, AdSearchParams params) {
    Team team = teamService.getTeam(teamSlug);
    return new CountResponse(
        adRepository.countMatching(
            AdQuery.builder()
                .domainId(pedalonsContext.getDomainId())
                .userId(pedalonsContext.getUserIdNullable())
                .teamIds(Set.of(team.getId()))
                .search(params.search())
                .adType(params.adType())
                .from(params.from())
                .to(params.to())
                .minPrice(params.minPrice())
                .maxPrice(params.maxPrice())
                .nearLat(params.nearLat())
                .nearLon(params.nearLon())
                .nearRadius(params.nearRadius())
                .tagIds(tagFilter(team, params))
                .platformAdmin(isPlatformAdmin())
                .build()));
  }

  /** The resolved {@code ?tags=} filter of the list and of its count, or null for none. */
  private @Nullable Set<Long> tagFilter(Team team, AdSearchParams params) {
    List<String> tags = params.tags();
    if (tags == null || tags.isEmpty()) {
      return null;
    }
    return tagService.resolveFilter(team, TagTarget.AD, tags);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.AD, action = ActionType.CREATE)
  public AdDto createAd(String teamSlug, AdRequest request) {
    Team team = teamService.getTeam(teamSlug);
    verifyAd(team, request);

    // Generate slug from name, ensure unique within team
    String slug = slugService.generateSlug(request.name(), team.getId(), adRepository);

    Ad ad =
        new Ad(
            pedalonsContext.getUser(), team, Instant.now(), request.name(), slug, request.adType());

    setProperties(request, ad);

    adRepository.persistAndFlush(ad);

    updateMedia(ad, request.media());
    tagService.replaceTags(ad, request.tagIds());

    adRepository.persist(ad);

    return toDto(ad);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.AD, action = ActionType.UPDATE)
  public AdDto updateAd(String teamSlug, String adSlug, AdRequest request) {
    Team team = teamService.getTeam(teamSlug);
    Ad ad = findBySlug(team, adSlug);

    verifyAd(team, request);

    // Read before setProperties overwrites it: a non-author was served the blurred point, and
    // saving the form unchanged must not swap the seller's exact point for the cell centre.
    Point<G2D> keptLocation = locationKeptOnUpdate(ad, request.locationGeometry());

    setProperties(request, ad);
    if (keptLocation != null) {
      ad.setLocationGeometry(keptLocation);
    }

    updateMedia(ad, request.media());
    tagService.replaceTags(ad, request.tagIds());

    adRepository.persist(ad);

    return toDto(ad);
  }

  /** Changes the status alone. An ad is a draft or published, never cancelled (see verifyAd). */
  @Transactional
  @CheckAccess(entityType = EntityType.AD, action = ActionType.UPDATE)
  public AdDto updateStatus(String teamSlug, String adSlug, Status status) {
    if (status == Status.CANCELLED) {
      throw new BusinessException(ErrorCode.STATUS_INVALID);
    }
    Team team = teamService.getTeam(teamSlug);
    Ad ad = findBySlug(team, adSlug);
    ad.setStatus(status);
    adRepository.persist(ad);
    return toDto(ad);
  }

  @CheckAccess(entityType = EntityType.AD, action = ActionType.UPDATE)
  @Transactional
  public AdDto updateSlug(String teamSlug, String slug, String newSlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.updateSlug(team, slug, newSlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.AD, action = ActionType.DELETE)
  public void deleteAd(String teamSlug, String adSlug) {
    Team team = teamService.getTeam(teamSlug);
    Ad ad = findBySlug(team, adSlug);
    ad.setDeleted(true);
    adRepository.persist(ad);
  }

  @CheckAccess(entityType = EntityType.AD, action = ActionType.DELETE)
  @Transactional
  public AdEditDto undeleteAd(String teamSlug, String adSlug) {
    Team team = teamService.getTeam(teamSlug);
    Ad ad = findBySlugIncludeDeleted(team, adSlug);
    requireNotRemovedByModeration(ad);
    ad.setDeleted(false);
    adRepository.persist(ad);
    return toEditDto(ad);
  }

  /**
   * Relays a message to an ad's author without publishing anyone's address.
   *
   * <p>The alternative shape — a {@code contact} column rendered on the ad — is cheaper to build
   * and worse to live with: it hands an email address or a phone number to every member of the
   * team, permanently, and no later change of mind takes it back. On a 1999-member team that is an
   * irrevocable disclosure. Here the contract carries no contact field at all: the server knows
   * both addresses, the caller learns neither, and the author can switch the channel off.
   *
   * <p>{@link ActionType#READ} is the right gate and not a lax one — being able to write to an ad
   * is exactly being able to see it. Anything looser would let a non-member address a team's
   * sellers; anything stricter would stop members answering ads they can read.
   */
  @Logged
  @Transactional
  @CheckAccess(entityType = EntityType.AD, action = ActionType.READ)
  public void contactAuthor(String teamSlug, String adSlug, AdContactRequest request) {
    Team team = teamService.getTeam(teamSlug);
    Ad ad = findBySlug(team, adSlug);
    User sender = pedalonsContext.getUser();
    User author = ad.getCreatedBy();

    if (author.getId().equals(sender.getId())) {
      throw new BusinessException(ErrorCode.AD_CONTACT_SELF);
    }
    if (!author.isContactableByMembers()) {
      throw new BusinessException(ErrorCode.AD_CONTACT_OPTED_OUT);
    }

    // Per sender, not per ad: a member who may read the classifieds may write to all of them, so a
    // per-ad cap caps nothing — three per ad across twenty ads is sixty relayed emails from one
    // account. What the threshold protects is the domain's sending reputation, and one account
    // consumes that whoever it writes to.
    long recent = adContactRepository.countRecentBySender(sender.getId(), contactWindowMinutes);
    if (recent >= contactMaxPerWindow) {
      Log.warnf(
          "Ad contact rate limit exceeded for user=%d ad=%d (%d in %d min)",
          sender.getId(), ad.getId(), recent, contactWindowMinutes);
      throw new TooManyRequestsException(
          ErrorCode.AD_CONTACT_RATE_LIMITED, Duration.ofMinutes(contactWindowMinutes).toSeconds());
    }

    adContactRepository.persist(new AdContact(sender, ad));

    try {
      adContactEmailService.sendContactMessage(ad, author, sender, request.message());
    } catch (RuntimeException e) {
      // Deliberately not swallowed, and the reason the persist above sits inside the transaction:
      // a relay that answers 204 and drops the message is worse than one that fails, because the
      // sender waits for a reply that was never going to come. Rolling back also means a failed
      // attempt neither counts against the quota nor leaves a row claiming a delivery.
      Log.errorf(e, "Ad contact delivery failed for ad=%d sender=%d", ad.getId(), sender.getId());
      throw new InternalException(ErrorCode.AD_CONTACT_DELIVERY_FAILED, e);
    }
  }

  /**
   * The edit view of an ad, with the exact location for its author only.
   *
   * <p>The exact point is, in practice, the seller's home. Being able to moderate an ad — fix a
   * title, unpublish it — does not need it, so a team admin (or a platform admin) editing someone
   * else's ad gets the same ~1 km cell centre as every other reader (docs/LEDGER_*.md SEC-26).
   */
  private AdEditDto toEditDto(Ad ad) {
    return AdEditDto.from(ad, assetService, isAuthor(ad), tagLookup.forContent(ad.getId()));
  }

  private boolean isAuthor(Ad ad) {
    Long userId = pedalonsContext.getUserIdNullable();
    return userId != null && userId.equals(ad.getCreatedBy().getId());
  }

  /**
   * The stored exact point when an update by a non-author sends back the blurred point it was
   * served, {@code null} when the submitted location should be applied as is.
   *
   * <p>Compared with the blur of the stored point rather than signalled by a flag on the request:
   * the server alone knows what it served, and a client that simply round-trips the edit form —
   * the web editor does — keeps the seller's point without knowing the rule exists. A non-author
   * who picks another place, or clears the location, still gets what they asked for; picking the
   * exact centre of the seller's cell is indistinguishable from not moving, and lands in the same
   * cell anyway.
   */
  private @Nullable Point<G2D> locationKeptOnUpdate(Ad ad, @Nullable Point<G2D> submitted) {
    Point<G2D> stored = ad.getLocationGeometry();
    if (isAuthor(ad) || stored == null || stored.isEmpty()) {
      return null;
    }
    Point<G2D> served = CoarseLocation.blur(stored);
    if (submitted == null || submitted.isEmpty() || served == null) {
      return null;
    }
    G2D a = submitted.getPosition();
    G2D b = served.getPosition();
    boolean unchanged =
        Math.abs(a.getLat() - b.getLat()) < SAME_POINT_DEGREES
            && Math.abs(a.getLon() - b.getLon()) < SAME_POINT_DEGREES;
    return unchanged ? stored : null;
  }

  private void verifyAd(Team team, AdRequest request) {
    // Validate rental period for rental ads
    if (request.adType() == AdType.RENTAL && request.rentalPeriod() == null) {
      throw new BusinessException(ErrorCode.RENTAL_PERIOD_MISSING);
    }

    if (request.status() == Status.CANCELLED) {
      throw new BusinessException(ErrorCode.STATUS_INVALID);
    }
  }

  private void setProperties(AdRequest request, Ad ad) {
    // An ad is members-only in every team, private or not, publicContentAllowed or not: the
    // request carries no visibility, and ContentVisibilityRules accepts TEAM alone for an ad
    // (docs/LEDGER_*.md API-176).
    ad.setVisibility(Visibility.TEAM);
    ad.setName(request.name());
    ad.setStatus(request.status());
    ad.setPublishAt(null);
    ad.setAdType(request.adType());
    ad.setPrice(request.price());
    if (request.adType() == AdType.RENTAL) {
      ad.setRentalPeriod(request.rentalPeriod());
    } else {
      ad.setRentalPeriod(null);
    }
    ad.setLocationDescription(request.locationDescription());
    ad.setLocationGeometry(request.locationGeometry());
  }
}

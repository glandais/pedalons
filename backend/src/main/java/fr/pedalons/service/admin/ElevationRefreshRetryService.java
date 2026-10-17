package fr.pedalons.service.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.admin.ElevationRefreshKind;
import fr.pedalons.dto.admin.ElevationRefreshRetryRequest;
import fr.pedalons.dto.admin.ElevationRefreshRetryResponse;
import fr.pedalons.dto.admin.ElevationRefreshRetryResponse.ElevationRefreshRetryItem;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.AbandonedRefresh;
import fr.pedalons.service.elevation.ElevationRefreshService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Starts again the HD elevation recomputations the worker gave up on (docs/LEDGER_*.md API-131):
 * the requests that used up {@link ElevationRefreshService#MAX_ATTEMPTS} attempts, whose target
 * stays on the fast profile (state FAST). Nothing retries them by itself; this is the lever.
 */
@ApplicationScoped
public class ElevationRefreshRetryService {

  private static final Logger LOG = Logger.getLogger(ElevationRefreshRetryService.class);

  private static final int DEFAULT_LIMIT = 100;

  /** Gap between two retried requests, so a big batch does not hit the worker at once. */
  static final Duration SPACING = Duration.ofMinutes(1);

  @Inject ElevationRefreshRepository refreshRepository;
  @Inject DomainResolver domainResolver;

  /** Targets the given domain, or the request's resolved domain when {@code domainId} is null. */
  @Admin
  @Transactional
  public ElevationRefreshRetryResponse retry(
      @Nullable String domainId, ElevationRefreshRetryRequest request) {
    Long targetDomainId =
        domainId != null ? TsidUtils.toLong(domainId) : domainResolver.getDomainId();
    int max = ElevationRefreshService.MAX_ATTEMPTS;
    ElevationRefreshKind kind = request.kind();
    int limit = request.limit() != null ? request.limit() : DEFAULT_LIMIT;

    int matched = refreshRepository.countAbandoned(targetDomainId, max, kind);
    // Read before the reset: it clears the last error
    List<AbandonedRefresh> abandoned =
        refreshRepository.findAbandoned(targetDomainId, max, limit, kind);
    if (!request.dryRun() && !abandoned.isEmpty()) {
      int reset =
          refreshRepository.resetAbandoned(
              abandoned.stream().map(AbandonedRefresh::id).toList(), Instant.now(), SPACING, max);
      LOG.infov(
          "HD elevation retry in domain {0}: {1} abandoned, {2} listed, {3} restarted",
          targetDomainId, matched, abandoned.size(), reset);
    } else {
      LOG.infov(
          "HD elevation retry (dryRun={0}) in domain {1}: {2} abandoned, {3} listed",
          request.dryRun(), targetDomainId, matched, abandoned.size());
    }
    return new ElevationRefreshRetryResponse(
        request.dryRun(),
        matched,
        abandoned.stream().map(ElevationRefreshRetryService::item).toList());
  }

  private static ElevationRefreshRetryItem item(AbandonedRefresh a) {
    return new ElevationRefreshRetryItem(
        a.kind(),
        TsidUtils.toString(a.targetId()),
        a.teamSlug(),
        a.routeSlug(),
        a.previewPublicId(),
        a.attempts(),
        a.lastError(),
        a.firstRequestedAt());
  }
}

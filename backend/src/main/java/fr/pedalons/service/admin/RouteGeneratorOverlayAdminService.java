package fr.pedalons.service.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshRequest;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResponse;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResponse.Action;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResponse.Reason;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResponse.RouteGeneratorOverlayRefreshItem;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResult;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Options;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Report;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;

/**
 * The manual trigger of the nightly overlay pass (lot 3b plan §6.5): for an operator after a
 * deploy or a new graph, a developer, the e2e stack. Platform admin only.
 */
@ApplicationScoped
public class RouteGeneratorOverlayAdminService {

  @Inject RouteGeneratorOverlayJob job;

  @Admin
  public RouteGeneratorOverlayRefreshResult refresh(RouteGeneratorOverlayRefreshRequest request) {
    Long teamId = request.teamId() == null ? null : TsidUtils.toLong(request.teamId());
    Options options = new Options(teamId, request.force(), request.dryRun());
    if (request.dryRun()) {
      Report report = job.runOnce(Instant.now(), options);
      return new RouteGeneratorOverlayRefreshResult(
          new RouteGeneratorOverlayRefreshResponse(
              report.ran(), report.graphId(), items(report.items())),
          false);
    }
    boolean started = job.startInBackground(options);
    return new RouteGeneratorOverlayRefreshResult(
        new RouteGeneratorOverlayRefreshResponse(started, null, List.of()), true);
  }

  private static List<RouteGeneratorOverlayRefreshItem> items(
      List<RouteGeneratorOverlayJob.Item> items) {
    return items.stream()
        .map(i ->
            new RouteGeneratorOverlayRefreshItem(
                TsidUtils.toString(i.teamId()),
                i.teamSlug(),
                Action.valueOf(i.action().name()),
                Reason.valueOf(i.reason().name()),
                i.state(),
                i.depositedAt(),
                i.expiresAt()))
        .toList();
  }
}

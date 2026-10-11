package fr.pedalons.service.notification.event;

import fr.pedalons.enums.NotificationType;
import fr.pedalons.enums.ReportTargetType;

/**
 * A report was filed; the team's moderators and the platform admins are told. Published without an
 * actor: the reporter is anonymous to the team.
 *
 * <p>Keyed by the team and the target rather than by the report, and coalescing while pending: a
 * burst of reports on the same content makes one notification. The team is in the key because a
 * member can be reported in several teams, each with its own moderators: without it, a report in
 * team B would fold into a pending one from team A and B's moderators would never hear of it. The
 * team and the target travel in the record only to build that key — the resolver reads the report.
 */
public record ContentReported(
    long reportId, long teamId, ReportTargetType targetType, long targetId)
    implements NotificationEvent {

  @Override
  public NotificationType type() {
    return NotificationType.CONTENT_REPORTED;
  }

  @Override
  public String dedupKey() {
    return type().name() + ":" + teamId + ":" + targetType.name() + ":" + targetId;
  }
}

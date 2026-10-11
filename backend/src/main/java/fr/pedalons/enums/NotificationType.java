package fr.pedalons.enums;

import static fr.pedalons.enums.NotificationChannel.EMAIL;
import static fr.pedalons.enums.NotificationChannel.IN_APP;
import static fr.pedalons.enums.NotificationChannel.PUSH;

import java.util.EnumSet;
import java.util.Set;

/**
 * The closed set of things a member can be notified about.
 *
 * <p>Stored by name in {@code notification_events.type} and {@code notification_preferences.type}:
 * renaming a constant is a data migration, adding one is not. Each constant has exactly one event
 * record in {@code fr.pedalons.service.notification.event}, and the resolver switches exhaustively
 * over those records — a type added here without its handling does not compile.
 *
 * <p>{@link #defaultChannels} is what a member receives until they touch their preferences. Only
 * the overrides are stored, so changing a default here changes it for everyone who never did.
 */
public enum NotificationType {
  /** A ride became visible to the team: created published, published from draft, or auto-published. */
  RIDE_PUBLISHED(EnumSet.of(IN_APP, PUSH), Audience.BROADCAST, false),
  /** A ride the recipient is registered to was cancelled. */
  RIDE_CANCELLED(EnumSet.of(IN_APP, EMAIL, PUSH), Audience.PERSONAL, true),
  /** A trip became visible to the team. Rarer and weightier than a ride, hence the e-mail. */
  TRIP_PUBLISHED(EnumSet.of(IN_APP, EMAIL, PUSH), Audience.BROADCAST, false),
  /** A trip the recipient is registered to was cancelled. */
  TRIP_CANCELLED(EnumSet.of(IN_APP, EMAIL, PUSH), Audience.PERSONAL, true),
  /** A post became visible to the team. */
  POST_PUBLISHED(EnumSet.of(IN_APP), Audience.BROADCAST, false),
  /** Someone replied to the recipient's comment. */
  COMMENT_REPLY(EnumSet.of(IN_APP, PUSH), Audience.PERSONAL, false),
  /** A ride the recipient is registered to starts within a day. Produced by a scheduler. */
  RIDE_REMINDER(EnumSet.of(IN_APP, PUSH), Audience.PERSONAL, true),
  /** The date or the meeting point of a ride the recipient is registered to changed. */
  RIDE_UPDATED(EnumSet.of(IN_APP, EMAIL, PUSH), Audience.PERSONAL, true),
  /**
   * The group of a ride the recipient was registered to was removed, and their registration with
   * it. As weighty as a cancellation: they believe they ride, and no longer do.
   */
  RIDE_GROUP_REMOVED(EnumSet.of(IN_APP, EMAIL, PUSH), Audience.PERSONAL, true),
  /**
   * Someone joined a ride the recipient created or leads a group of. In-app only by default: a
   * popular ride would otherwise buzz its organiser thirty times.
   */
  RIDE_JOINED(EnumSet.of(IN_APP), Audience.PERSONAL, false),
  /** Someone commented on a ride, trip, post or route the recipient created. */
  COMMENT_ON_MY_PUBLICATION(EnumSet.of(IN_APP, PUSH), Audience.PERSONAL, false),
  /**
   * The recipient was invited to a team. No e-mail by default: the invitation sends its own, with
   * the link that accepts it.
   */
  TEAM_INVITATION(EnumSet.of(IN_APP, PUSH), Audience.PERSONAL, false),
  /**
   * Something in a team the recipient moderates was reported and waits for their decision. Urgent:
   * a report of harassment must not wait for tomorrow's digest. Never names the reporter.
   */
  CONTENT_REPORTED(EnumSet.of(IN_APP, PUSH, EMAIL), Audience.PERSONAL, true);

  /** Who a type speaks to. */
  public enum Audience {
    /**
     * The whole team, because something was announced to it. The kind a member silences by muting a
     * team, and the kind a team webhook relays.
     */
    BROADCAST,
    /** Someone concerned in particular: registered, replied to, invited. Never muted by a team. */
    PERSONAL
  }

  private final Set<NotificationChannel> defaultChannels;
  private final Audience audience;
  private final boolean urgent;

  NotificationType(Set<NotificationChannel> defaultChannels, Audience audience, boolean urgent) {
    this.defaultChannels = Set.copyOf(defaultChannels);
    this.audience = audience;
    this.urgent = urgent;
  }

  public boolean isEnabledByDefault(NotificationChannel channel) {
    return defaultChannels.contains(channel);
  }

  /** Announced to the whole team — see {@link Audience#BROADCAST}. */
  public boolean isBroadcast() {
    return audience == Audience.BROADCAST;
  }

  /**
   * Cannot wait for tomorrow morning's digest: the cancellation of a ride that leaves at eight would
   * arrive after it left.
   */
  public boolean isUrgent() {
    return urgent;
  }

  /**
   * Relayed to the team webhook: what the whole team would want to read in its chat — what was
   * announced, and what changed or was called off since.
   */
  public boolean isRelayedToTeamWebhook() {
    return switch (this) {
      case RIDE_PUBLISHED,
          TRIP_PUBLISHED,
          POST_PUBLISHED,
          RIDE_CANCELLED,
          TRIP_CANCELLED,
          RIDE_UPDATED ->
          true;
      case COMMENT_REPLY,
          RIDE_REMINDER,
          RIDE_GROUP_REMOVED,
          RIDE_JOINED,
          COMMENT_ON_MY_PUBLICATION,
          TEAM_INVITATION,
          CONTENT_REPORTED ->
          false;
    };
  }

  /**
   * Whether the dedup key is only held while the event waits to be fanned out — see {@code
   * NotificationEvent.coalescesWhilePending()}, which reads it. On the type rather than the record so
   * the dispatcher can tell at claim time, before it reads the payload.
   */
  public boolean coalescesWhilePending() {
    return switch (this) {
      case RIDE_UPDATED, CONTENT_REPORTED -> true;
      case RIDE_PUBLISHED,
          RIDE_CANCELLED,
          TRIP_PUBLISHED,
          TRIP_CANCELLED,
          POST_PUBLISHED,
          COMMENT_REPLY,
          RIDE_REMINDER,
          RIDE_GROUP_REMOVED,
          RIDE_JOINED,
          COMMENT_ON_MY_PUBLICATION,
          TEAM_INVITATION ->
          false;
    };
  }
}

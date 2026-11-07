package fr.pedalons.service.notification;

import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.service.timezone.ZoneLabels;
import jakarta.enterprise.context.ApplicationScoped;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.jspecify.annotations.Nullable;

/**
 * Server-side wording of the notifications, for the channels that need finished text: e-mail, push,
 * the team webhook. The inbox does not use it: clients localize from the type and structured fields.
 *
 * <p>A properties file per language rather than one mail template per type: the e-mail goes
 * through a single generic template whose parameters are already rendered here, so adding a type
 * means adding four lines to two files, not two more Qute templates.
 */
@ApplicationScoped
public class NotificationTexts {

  static final String DEFAULT_LANGUAGE = "fr";
  static final ZoneId DEFAULT_ZONE = ZoneId.of("Europe/Paris");
  static final String[] KEYS = {"subject", "title", "body", "cta"};

  /**
   * The day of a rendezvous (docs/BRANDING.md §8.3, ledger BRAND-8): weekday and month abbreviated,
   * « sam. 12 avr. » / « Sat, Apr 12 » — with the year when it is not the current one.
   */
  private static final Map<String, DateTimeFormatter> DAY_FORMATS =
      Map.of(
          "fr", DateTimeFormatter.ofPattern("EEE d MMM", Locale.FRENCH),
          "en", DateTimeFormatter.ofPattern("EEE, MMM d", Locale.ENGLISH));

  private static final Map<String, DateTimeFormatter> DAY_WITH_YEAR_FORMATS =
      Map.of(
          "fr", DateTimeFormatter.ofPattern("EEE d MMM yyyy", Locale.FRENCH),
          "en", DateTimeFormatter.ofPattern("EEE, MMM d, yyyy", Locale.ENGLISH));

  /** The time of a rendezvous: « 09:00 », never « 09h00 »; English reads « 9:00 AM ». */
  private static final Map<String, DateTimeFormatter> TIME_FORMATS =
      Map.of(
          "fr", DateTimeFormatter.ofPattern("HH:mm", Locale.FRENCH),
          "en", DateTimeFormatter.ofPattern("h:mm a", Locale.ENGLISH));

  /** The reader's equivalent of a rendezvous, when it falls on another day (« ven. 01:00 »). */
  private static final Map<String, DateTimeFormatter> DAY_TIME_FORMATS =
      Map.of(
          "fr", DateTimeFormatter.ofPattern("EEE HH:mm", Locale.FRENCH),
          "en", DateTimeFormatter.ofPattern("EEE h:mm a", Locale.ENGLISH));

  /** Between the day and the time of a rendezvous: « sam. 12 avr. · 09:00 ». */
  private static final String DAY_TIME_SEPARATOR = " · ";

  private static final Pattern PLACEHOLDER = Pattern.compile("\\{(\\w+)}");

  private final Map<String, Properties> bundles = new ConcurrentHashMap<>();

  /** What « now » is: whether a date needs its year, and what « demain » means. */
  private final Clock clock;

  public NotificationTexts() {
    this(Clock.systemUTC());
  }

  /** For tests, which must not depend on the year they run in. */
  NotificationTexts(Clock clock) {
    this.clock = clock;
  }

  /**
   * One notification, worded. {@code heading} is the absolute line a reader may meet later — the
   * bold title of a digest item, the start of an e-mail's preheader: for a rendezvous its date and
   * name (« sam. 12 avr. · 09:00 : Boucle »), never « demain », else the title.
   */
  public record Rendered(String subject, String title, String body, String cta, String heading) {

    /** The hidden preview text of an e-mail: the date and the name first, then what happened. */
    public String preheader() {
      return heading + " — " + body;
    }
  }

  /**
   * The zones a rendezvous is written with (docs/LEDGER_*.md API-60, plan §7): it reads in {@code
   * subject}'s, the rendezvous' own; that zone is named when its offset differs from {@code
   * reference}'s at the rendezvous; and the {@code reader}'s equivalent is added when there is a
   * reader with a zone of their own.
   */
  public record Zones(ZoneId subject, @Nullable ZoneId reader, ZoneId reference) {

    /**
     * A person: the subject's zone — Paris for a row fanned out before the column existed, when
     * every team was Paris — compared with theirs, else with Paris, the zone their messages read
     * in so far.
     */
    public static Zones forReader(
        @Nullable String subjectTimezone, @Nullable String readerTimezone) {
      ZoneId reader = parse(readerTimezone);
      return new Zones(
          zoneOr(subjectTimezone, DEFAULT_ZONE), reader, reader != null ? reader : DEFAULT_ZONE);
    }

    /**
     * A team webhook: nobody's own zone, the team's as the reference — and as the subject's for a
     * row fanned out before the column existed.
     */
    public static Zones forTeam(@Nullable String subjectTimezone, @Nullable String teamTimezone) {
      ZoneId team = zoneOr(teamTimezone, DEFAULT_ZONE);
      return new Zones(zoneOr(subjectTimezone, team), null, team);
    }
  }

  public Rendered render(NotificationMessage message) {
    return render(
        message.type(),
        message.recipientLanguage(),
        Zones.forReader(message.subjectTimezone(), message.recipientTimezone()),
        message.actorName(),
        message.teamName(),
        message.subjectName(),
        message.subjectDateTime(),
        message.excerpt(),
        message.siteName(),
        message.changes());
  }

  /**
   * The same wording for a reader who is not a member — a team webhook, which has a language of its
   * own and no time zone but its team's ({@link Zones#forTeam}).
   */
  public Rendered render(
      NotificationType type,
      @Nullable String languageTag,
      Zones zones,
      @Nullable String actorName,
      String teamName,
      String subjectName,
      @Nullable Instant subjectDateTime,
      @Nullable String excerpt,
      String siteName,
      List<NotificationChange> changes) {
    String language = language(languageTag);
    Properties texts = bundle(language);
    Instant now = clock.instant();
    Map<String, String> values = new HashMap<>();
    values.put("actor", actorName != null ? actorName : teamName);
    values.put("team", teamName);
    values.put("subject", subjectName);
    if (subjectDateTime == null) {
      values.put("date", "");
      values.put("when", "");
      values.put("soon", "");
    } else {
      values.put("date", formatRendezvous(subjectDateTime, language, zones, now));
      values.put("when", formatDeparture(subjectDateTime, language, zones.subject(), now));
      values.put("soon", formatSoon(subjectDateTime, language, zones.subject(), now));
    }
    values.put("excerpt", excerpt != null ? excerpt : "");
    values.put("site", siteName);
    // Each change is a clause of its own, filled with the same values, then the clauses joined.
    values.put(
        "changes",
        String.join(
            texts.getProperty("change.separator", "; "),
            changes.stream().map(c -> fill(texts, "change." + c.name(), values)).toList()));
    String prefix = type.name() + ".";
    // A new time is news enough to lead the title: RIDE_UPDATED.title.DATE_TIME over .title.
    String variant = changes.contains(NotificationChange.DATE_TIME) ? ".DATE_TIME" : "";
    String title = fill(texts, variantKey(texts, prefix + "title", variant), values);
    return new Rendered(
        fill(texts, variantKey(texts, prefix + "subject", variant), values),
        title,
        fill(texts, prefix + "body", values),
        fill(texts, prefix + "cta", values),
        isRendezvous(type) && subjectDateTime != null ? fill(texts, "heading", values) : title);
  }

  private static String variantKey(Properties texts, String key, String variant) {
    return !variant.isEmpty() && texts.getProperty(key + variant) != null ? key + variant : key;
  }

  /**
   * The types whose subject is a rendezvous — a ride or a trip, read for when it leaves: their
   * {@link Rendered#heading()} is its date and name. A post's date is when it was published, a
   * comment's or a report's is no one's appointment.
   */
  static boolean isRendezvous(NotificationType type) {
    return switch (type) {
      case RIDE_PUBLISHED,
          RIDE_CANCELLED,
          TRIP_PUBLISHED,
          TRIP_CANCELLED,
          RIDE_REMINDER,
          RIDE_UPDATED,
          RIDE_GROUP_REMOVED,
          RIDE_JOINED ->
          true;
      case POST_PUBLISHED,
          COMMENT_REPLY,
          COMMENT_ON_MY_PUBLICATION,
          TEAM_INVITATION,
          CONTENT_REPORTED ->
          false;
    };
  }

  /** The test message of a team webhook: its {@code title} or {@code body}. */
  public String webhookTestText(String languageTag, String key, String teamName, String siteName) {
    return fill(
        bundle(language(languageTag)),
        "webhook.test." + key,
        Map.of("team", teamName, "site", siteName));
  }

  /** A line of the daily digest's frame: its subject and its heading. */
  public String digestText(@Nullable String languageTag, String key, int count) {
    return fill(
        bundle(language(languageTag)), "digest." + key, Map.of("count", String.valueOf(count)));
  }

  /**
   * A date and time as every message to a person writes it — in their language, in their zone, the
   * default ones when they have none (« dim. 11 oct. · 08:30 »).
   */
  public static String formatDateTime(
      Instant instant, @Nullable String languageTag, @Nullable String timezone) {
    return formatDateTime(instant, languageTag, timezone, Instant.now());
  }

  static String formatDateTime(
      Instant instant, @Nullable String languageTag, @Nullable String timezone, Instant now) {
    return formatDeparture(instant, language(languageTag), zone(timezone), now);
  }

  /**
   * The single departure format (docs/BRANDING.md §8.3, ledger BRAND-8), in {@code zone}: « sam. 12
   * avr. · 09:00 », « sam. 10 avr. 2027 · 09:00 » when the year is not {@code now}'s there.
   */
  static String formatDeparture(Instant instant, String language, ZoneId zone, Instant now) {
    boolean thisYear = instant.atZone(zone).getYear() == now.atZone(zone).getYear();
    return (thisYear ? DAY_FORMATS : DAY_WITH_YEAR_FORMATS)
            .get(language)
            .withZone(zone)
            .format(instant)
        + DAY_TIME_SEPARATOR
        + TIME_FORMATS.get(language).withZone(zone).format(instant);
  }

  /**
   * The departure relative to {@code now}, for the one message whose point is that it is near — the
   * reminder: « Demain 09:00 », « Aujourd'hui 09:00 », else {@link #formatDeparture}. Judged in the
   * rendezvous' zone, so it holds whenever the message leaves.
   */
  String formatSoon(Instant instant, String language, ZoneId zone, Instant now) {
    long days =
        ChronoUnit.DAYS.between(now.atZone(zone).toLocalDate(), instant.atZone(zone).toLocalDate());
    String key = days == 0 ? "relative.today" : days == 1 ? "relative.tomorrow" : null;
    if (key == null) {
      return formatDeparture(instant, language, zone, now);
    }
    return fill(
        bundle(language),
        key,
        Map.of("time", TIME_FORMATS.get(language).withZone(zone).format(instant)));
  }

  String formatRendezvous(Instant instant, @Nullable String languageTag, Zones zones) {
    return formatRendezvous(instant, languageTag, zones, clock.instant());
  }

  /**
   * A rendezvous as every message writes it (docs/LEDGER_*.md API-60, plan §7): in its own zone,
   * that zone named when its offset differs from the reference's, and the reader's equivalent when
   * they have a zone — with the day when it changes. « sam. 11 oct. · 08:00, heure de Tokyo (ven.
   * 01:00 chez vous) »; « sam. 11 oct. · 08:00 » when the offsets agree.
   */
  String formatRendezvous(Instant instant, @Nullable String languageTag, Zones zones, Instant now) {
    String language = language(languageTag);
    ZoneId subject = zones.subject();
    String date = formatDeparture(instant, language, subject, now);
    if (ZoneLabels.sameOffsetAt(instant, subject, zones.reference())) {
      return date;
    }
    Properties texts = bundle(language);
    String zone =
        fill(
            texts,
            "zone.name",
            Map.of(
                "city", ZoneLabels.cityName(subject.getId(), language),
                "ofCity", ZoneLabels.cityOf(subject.getId(), language)));
    ZoneId reader = zones.reader();
    if (reader == null) {
      return fill(texts, "zone.date", Map.of("date", date, "zone", zone));
    }
    boolean otherDay =
        !instant.atZone(subject).toLocalDate().equals(instant.atZone(reader).toLocalDate());
    String time =
        (otherDay ? DAY_TIME_FORMATS : TIME_FORMATS).get(language).withZone(reader).format(instant);
    String local = fill(texts, "zone.local", Map.of("time", time));
    return fill(texts, "zone.dateWithLocal", Map.of("date", date, "zone", zone, "local", local));
  }

  /** "fr-CA" reads the French file; a language nobody translated reads the default. */
  static String language(@Nullable String tag) {
    if (tag == null) {
      return DEFAULT_LANGUAGE;
    }
    String primary = tag.split("-")[0].toLowerCase(Locale.ROOT);
    return DAY_FORMATS.containsKey(primary) ? primary : DEFAULT_LANGUAGE;
  }

  static ZoneId zone(@Nullable String timezone) {
    return zoneOr(timezone, DEFAULT_ZONE);
  }

  private static ZoneId zoneOr(@Nullable String timezone, ZoneId fallback) {
    ZoneId zone = parse(timezone);
    return zone != null ? zone : fallback;
  }

  /** The zone {@code timezone} names, or null when it is absent or unknown. */
  private static @Nullable ZoneId parse(@Nullable String timezone) {
    if (timezone == null) {
      return null;
    }
    try {
      return ZoneId.of(timezone);
    } catch (DateTimeException e) {
      return null;
    }
  }

  private static String fill(Properties texts, String key, Map<String, String> values) {
    String template = texts.getProperty(key);
    if (template == null) {
      throw new IllegalStateException("Missing notification text " + key);
    }
    // One pass, so a ride named "{team}" stays a ride named "{team}".
    return PLACEHOLDER
        .matcher(template)
        .replaceAll(m -> Matcher.quoteReplacement(values.getOrDefault(m.group(1), m.group())));
  }

  Properties bundle(String language) {
    return bundles.computeIfAbsent(language, NotificationTexts::load);
  }

  private static Properties load(String language) {
    String path = "notifications/texts_" + language + ".properties";
    try (InputStream in =
        Thread.currentThread().getContextClassLoader().getResourceAsStream(path)) {
      if (in == null) {
        throw new IllegalStateException("Missing " + path);
      }
      Properties properties = new Properties();
      properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
      return properties;
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  /** Every language with a texts file — what {@code NotificationTextsTest} checks for completeness. */
  static Iterable<String> languages() {
    return DAY_FORMATS.keySet();
  }

  /** The keys outside the per-type blocks: change clauses, zone mention, digest, webhook test. */
  static boolean isFrameComplete(Properties texts) {
    for (NotificationChange change : NotificationChange.values()) {
      if (texts.getProperty("change." + change.name()) == null) {
        return false;
      }
    }
    for (String key :
        new String[] {
          "zone.name",
          "zone.date",
          "zone.dateWithLocal",
          "zone.local",
          "relative.today",
          "relative.tomorrow",
          "heading",
          "digest.subject",
          "digest.title",
          "digest.intro",
          "webhook.test.title",
          "webhook.test.body"
        }) {
      if (texts.getProperty(key) == null) {
        return false;
      }
    }
    return true;
  }

  static boolean isComplete(Properties texts, NotificationType type) {
    for (String key : KEYS) {
      if (texts.getProperty(type.name() + "." + key) == null) {
        return false;
      }
    }
    return true;
  }
}

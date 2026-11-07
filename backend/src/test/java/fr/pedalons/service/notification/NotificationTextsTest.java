package fr.pedalons.service.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/** Plain unit test: no Quarkus, the texts are classpath files. */
class NotificationTextsTest {

  /** The rides of these tests leave on Sunday 2026-09-20, 08:30 in Paris. */
  private static final Instant RIDE = Instant.parse("2026-09-20T06:30:00Z");

  /** The Tuesday before: same year, neither today nor tomorrow. */
  private static final Instant NOW = Instant.parse("2026-09-15T10:00:00Z");

  private final NotificationTexts texts = textsAt(NOW);

  private static NotificationTexts textsAt(Instant now) {
    return new NotificationTexts(Clock.fixed(now, ZoneOffset.UTC));
  }

  private static NotificationMessage message(
      NotificationType type, @Nullable String language, String subjectName) {
    return message(type, language, subjectName, "Europe/Paris", "Europe/Paris");
  }

  private static NotificationMessage message(
      NotificationType type,
      @Nullable String language,
      String subjectName,
      @Nullable String recipientTimezone,
      @Nullable String subjectTimezone) {
    return new NotificationMessage(
        1L,
        2L,
        3L,
        NotificationChannel.EMAIL,
        type,
        "rider@example.com",
        "Rider",
        language,
        recipientTimezone,
        "Alice",
        "club",
        "Le Club",
        NotificationSubjectType.RIDE,
        "sortie",
        subjectName,
        RIDE,
        subjectTimezone,
        "8h30 au parking",
        "https://club.example",
        "Le Club",
        List.of());
  }

  private static NotificationTexts.Rendered render(
      NotificationTexts texts,
      NotificationType type,
      String language,
      @Nullable String subjectTimezone,
      List<NotificationChange> changes) {
    return texts.render(
        type,
        language,
        NotificationTexts.Zones.forReader(subjectTimezone, "Europe/Paris"),
        "Alice",
        "Le Club",
        "Col",
        RIDE,
        "A",
        "Pédalons",
        changes);
  }

  @Test
  void everyTypeIsWordedInEveryLanguage() {
    for (String language : NotificationTexts.languages()) {
      for (NotificationType type : NotificationType.values()) {
        assertTrue(
            NotificationTexts.isComplete(texts.bundle(language), type),
            type + " is missing a key in texts_" + language + ".properties");
      }
    }
  }

  @Test
  void rendersInTheRecipientsLanguageAndTimezone() {
    NotificationTexts.Rendered fr =
        texts.render(message(NotificationType.RIDE_PUBLISHED, "fr-FR", "Col du Galibier"));
    assertEquals("dim. 20 sept. · 08:30 : Col du Galibier", fr.subject());
    assertEquals("dim. 20 sept. · 08:30 : Col du Galibier", fr.title());
    assertEquals("Nouvelle sortie publiée par Alice, départ le dim. 20 sept. · 08:30.", fr.body());

    NotificationTexts.Rendered en =
        texts.render(message(NotificationType.RIDE_PUBLISHED, "en", "Col du Galibier"));
    assertEquals("Sun, Sep 20 · 8:30 AM: Col du Galibier", en.subject());
    assertEquals("New ride published by Alice, starting on Sun, Sep 20 · 8:30 AM.", en.body());
  }

  // ─── The single departure format (docs/BRANDING.md §8.3, ledger NOTIF-14) ───────────────────

  /** The year only when it is not the current one — the year of the moment the message leaves. */
  @Test
  void otherYear_writesTheYear() {
    Instant nextApril = Instant.parse("2027-04-10T07:00:00Z");
    NotificationTexts.Zones paris = NotificationTexts.Zones.forReader("Europe/Paris", null);
    assertEquals("sam. 10 avr. 2027 · 09:00", texts.formatRendezvous(nextApril, "fr", paris));
    assertEquals("Sat, Apr 10, 2027 · 9:00 AM", texts.formatRendezvous(nextApril, "en", paris));
    assertEquals(
        "sam. 10 avr. · 09:00",
        textsAt(Instant.parse("2027-01-05T10:00:00Z")).formatRendezvous(nextApril, "fr", paris));
    assertEquals(
        "Annulée, sam. 10 avr. 2027 · 09:00 : Col",
        texts
            .render(
                NotificationType.RIDE_CANCELLED,
                "fr",
                paris,
                null,
                "Le Club",
                "Col",
                nextApril,
                null,
                "Pédalons",
                List.of())
            .title());
  }

  /** The year is judged in the rendezvous' zone: Tokyo is already in 2027 when Paris is not. */
  @Test
  void year_isJudgedInTheRendezvousZone() {
    NotificationTexts newYearsEve = textsAt(Instant.parse("2026-12-31T20:00:00Z"));
    Instant ride = Instant.parse("2027-01-02T00:00:00Z"); // 09:00 in Tokyo
    assertEquals(
        "sam. 2 janv. · 09:00",
        newYearsEve.formatRendezvous(
            ride, "fr", NotificationTexts.Zones.forTeam("Asia/Tokyo", "Asia/Tokyo")));
  }

  /** The data-export mail's expiry reads like a notification date (API-92). */
  @Test
  void formatDateTime_followsTheReadersLanguageAndZone() {
    Instant instant = Instant.parse("2026-10-11T06:30:00Z");
    assertEquals(
        "dim. 11 oct. · 08:30",
        NotificationTexts.formatDateTime(instant, "fr-FR", "Europe/Paris", NOW));
    assertEquals(
        "Sun, Oct 11 · 3:30 PM",
        NotificationTexts.formatDateTime(instant, "en", "Asia/Tokyo", NOW));
    // No zone, or one nobody knows: Paris.
    assertEquals(
        "dim. 11 oct. · 08:30", NotificationTexts.formatDateTime(instant, null, "Mars/Base", NOW));
    assertEquals(
        "dim. 11 oct. 2026 · 08:30",
        NotificationTexts.formatDateTime(
            instant, "fr", "Europe/Paris", Instant.parse("2027-01-01T00:00:00Z")));
  }

  // ─── Dates in titles (ledger NOTIF-14) ──────────────────────────────────────────────────────

  /** The reminder leaves the day before: « Demain 08:30 » in its title, and only there. */
  @Test
  void reminder_saysTomorrow_inItsTitleAndSubject_only() {
    NotificationTexts dayBefore = textsAt(Instant.parse("2026-09-19T10:00:00Z"));
    NotificationTexts.Rendered fr =
        render(dayBefore, NotificationType.RIDE_REMINDER, "fr", "Europe/Paris", List.of());
    assertEquals("Demain 08:30 : Col", fr.title());
    assertEquals("Demain 08:30 : Col", fr.subject());
    assertEquals("Vous participez à cette sortie, qui part le dim. 20 sept. · 08:30.", fr.body());
    assertEquals("dim. 20 sept. · 08:30 : Col", fr.heading());

    NotificationTexts.Rendered en =
        render(dayBefore, NotificationType.RIDE_REMINDER, "en", "Europe/Paris", List.of());
    assertEquals("Tomorrow 8:30 AM: Col", en.title());
    assertEquals("Sun, Sep 20 · 8:30 AM: Col", en.heading());
  }

  /** « Demain » is computed when the message leaves: late, it says « Aujourd'hui », or the date. */
  @Test
  void reminder_isRelativeToWhenItLeaves() {
    assertEquals(
        "Aujourd'hui 08:30 : Col",
        render(
                textsAt(Instant.parse("2026-09-20T04:00:00Z")),
                NotificationType.RIDE_REMINDER,
                "fr",
                "Europe/Paris",
                List.of())
            .title());
    assertEquals(
        "Today 8:30 AM: Col",
        render(
                textsAt(Instant.parse("2026-09-20T04:00:00Z")),
                NotificationType.RIDE_REMINDER,
                "en",
                "Europe/Paris",
                List.of())
            .title());
    assertEquals(
        "dim. 20 sept. · 08:30 : Col",
        render(texts, NotificationType.RIDE_REMINDER, "fr", "Europe/Paris", List.of()).title());
    // Judged in the ride's zone: 01:00 on the 20th in Tokyo is still the 19th in Paris.
    assertEquals(
        "Aujourd'hui 15:30 : Col",
        render(
                textsAt(Instant.parse("2026-09-19T16:00:00Z")),
                NotificationType.RIDE_REMINDER,
                "fr",
                "Asia/Tokyo",
                List.of())
            .title());
  }

  /**
   * No text but the reminder's title says « demain » or « aujourd'hui »: a digest, a webhook or a
   * notification shade may be read days later.
   */
  @Test
  void noRelativeWord_outsideTheRemindersTitle() {
    NotificationTexts dayBefore = textsAt(Instant.parse("2026-09-19T10:00:00Z"));
    for (String language : NotificationTexts.languages()) {
      for (NotificationType type : NotificationType.values()) {
        for (List<NotificationChange> changes :
            List.of(List.<NotificationChange>of(), List.of(NotificationChange.DATE_TIME))) {
          NotificationTexts.Rendered r = render(dayBefore, type, language, "Europe/Paris", changes);
          List<String> absolute =
              type == NotificationType.RIDE_REMINDER
                  ? List.of(r.body(), r.cta(), r.heading())
                  : List.of(r.subject(), r.title(), r.body(), r.cta(), r.heading());
          for (String text : absolute) {
            assertFalse(
                text.matches("(?is).*\\b(demain|aujourd'hui|tomorrow|today)\\b.*"),
                type + " " + language + ": " + text);
          }
        }
      }
    }
  }

  /** The types where the time matters lead their title with it; the others keep theirs. */
  @Test
  void rendezvousTitles_leadWithTheDate() {
    String when = "dim. 20 sept. · 08:30";
    assertEquals(
        "Annulée, " + when + " : Col",
        render(texts, NotificationType.RIDE_CANCELLED, "fr", "Europe/Paris", List.of()).title());
    assertEquals(
        "Annulé, " + when + " : Col",
        render(texts, NotificationType.TRIP_CANCELLED, "fr", "Europe/Paris", List.of()).subject());
    assertEquals(
        when + " : Col",
        render(texts, NotificationType.TRIP_PUBLISHED, "fr", "Europe/Paris", List.of()).title());
    assertEquals(
        "Groupe retiré, " + when + " : Col",
        render(texts, NotificationType.RIDE_GROUP_REMOVED, "fr", "Europe/Paris", List.of())
            .title());
    assertEquals(
        "Nouvelle inscription, " + when + " : Col",
        render(texts, NotificationType.RIDE_JOINED, "fr", "Europe/Paris", List.of()).title());
    assertEquals(
        "Cancelled, Sun, Sep 20 · 8:30 AM: Col",
        render(texts, NotificationType.RIDE_CANCELLED, "en", "Europe/Paris", List.of()).title());
    // Neither a post nor a comment is an appointment.
    assertEquals(
        "Nouvelle réponse",
        render(texts, NotificationType.COMMENT_REPLY, "fr", "Europe/Paris", List.of()).title());
  }

  /** A new time leads the title of a RIDE_UPDATED; a new meeting point keeps the plain one. */
  @Test
  void rideUpdated_withANewTime_leadsWithIt() {
    NotificationTexts.Rendered moved =
        render(
            texts,
            NotificationType.RIDE_UPDATED,
            "fr",
            "Europe/Paris",
            List.of(NotificationChange.DATE_TIME, NotificationChange.START_PLACE));
    assertEquals("Nouvel horaire, dim. 20 sept. · 08:30 : Col", moved.title());
    assertEquals("Nouvel horaire, dim. 20 sept. · 08:30 : Col", moved.subject());
    assertEquals(
        "New time, Sun, Sep 20 · 8:30 AM: Col",
        render(
                texts,
                NotificationType.RIDE_UPDATED,
                "en",
                "Europe/Paris",
                List.of(NotificationChange.DATE_TIME))
            .title());
    NotificationTexts.Rendered placeOnly =
        render(
            texts,
            NotificationType.RIDE_UPDATED,
            "fr",
            "Europe/Paris",
            List.of(NotificationChange.START_PLACE));
    assertEquals("Sortie modifiée : Col", placeOnly.title());
    assertEquals("Sortie modifiée : Col", placeOnly.subject());
  }

  /** A title has no room for the zone mention: the rendezvous' own time; the body names it. */
  @Test
  void title_givesTheRendezvousTime_theBodyItsZone() {
    NotificationTexts.Rendered tokyo =
        texts.render(
            message(NotificationType.RIDE_CANCELLED, "fr", "Col", "Europe/Paris", "Asia/Tokyo"));
    assertEquals("Annulée, dim. 20 sept. · 15:30 : Col", tokyo.title());
    assertTrue(
        tokyo.body().contains("dim. 20 sept. · 15:30, heure de Tokyo (08:30 chez vous)"),
        tokyo.body());
  }

  /** The heading of a digest item and the preheader open on the date and the name. */
  @Test
  void headingAndPreheader_openOnTheDateAndTheName() {
    NotificationTexts.Rendered cancelled =
        render(texts, NotificationType.RIDE_CANCELLED, "fr", "Europe/Paris", List.of());
    assertEquals("dim. 20 sept. · 08:30 : Col", cancelled.heading());
    assertEquals(
        "dim. 20 sept. · 08:30 : Col — La sortie du dim. 20 sept. · 08:30, à laquelle vous"
            + " participiez, est annulée.",
        cancelled.preheader());
    NotificationTexts.Rendered reply =
        render(texts, NotificationType.COMMENT_REPLY, "fr", "Europe/Paris", List.of());
    assertEquals(reply.title(), reply.heading());
  }

  // ─── The rendezvous in its own zone (docs/LEDGER_*.md API-60, plan §7) ──────────────────────

  private String body(
      @Nullable String language, @Nullable String reader, @Nullable String subject) {
    return texts
        .render(message(NotificationType.RIDE_REMINDER, language, "Col", reader, subject))
        .body();
  }

  /** A Tokyo ride read from Paris: Tokyo's time, named, and the reader's on their own day. */
  @Test
  void rendezvousAbroad_readsInItsZone_withTheReadersEquivalent() {
    // 2026-09-20T06:30Z is 15:30 in Tokyo, 08:30 in Paris: same day.
    assertEquals(
        "Vous participez à cette sortie, qui part le dim. 20 sept. · 15:30, heure de Tokyo (08:30"
            + " chez vous).",
        body("fr", "Europe/Paris", "Asia/Tokyo"));
    assertEquals(
        "Sun, Sep 20 · 3:30 PM, Tokyo time (8:30 AM your time)",
        texts.formatRendezvous(
            RIDE, "en", NotificationTexts.Zones.forReader("Asia/Tokyo", "Europe/Paris")));
  }

  /** The reader's equivalent carries the short day when it is another day for them. */
  @Test
  void readersEquivalent_carriesTheDay_whenItChanges() {
    // 2026-09-20T06:30Z is 23:30 the day before in Los Angeles.
    assertEquals(
        "dim. 20 sept. · 15:30, heure de Tokyo (sam. 23:30 chez vous)",
        texts.formatRendezvous(
            RIDE, "fr", NotificationTexts.Zones.forReader("Asia/Tokyo", "America/Los_Angeles")));
    assertEquals(
        "Sun, Sep 20 · 3:30 PM, Tokyo time (Sat 11:30 PM your time)",
        texts.formatRendezvous(
            RIDE, "en", NotificationTexts.Zones.forReader("Asia/Tokyo", "America/Los_Angeles")));
  }

  /** Offsets, not identifiers: a Paris ride read from Brussels says nothing more than today. */
  @Test
  void sameOffset_noMention() {
    assertTrue(
        body("fr", "Europe/Brussels", "Europe/Paris").endsWith("dim. 20 sept. · 08:30."),
        body("fr", "Europe/Brussels", "Europe/Paris"));
  }

  /** A reader in Paris is told about a ride in Paris read from Tokyo — in the ride's time. */
  @Test
  void readerAbroad_getsTheRidesTime_andTheirs() {
    assertTrue(
        body("fr", "Asia/Tokyo", "Europe/Paris")
            .endsWith("dim. 20 sept. · 08:30, heure de Paris (15:30 chez vous)."),
        body("fr", "Asia/Tokyo", "Europe/Paris"));
  }

  /** No zone of their own: the zone is named against Paris, with no « chez vous ». */
  @Test
  void readerWithoutAZone_getsTheZoneNameOnly() {
    assertTrue(
        body("fr", null, "Asia/Tokyo").endsWith("· 15:30, heure de Tokyo."),
        body("fr", null, "Asia/Tokyo"));
    assertTrue(
        body("fr", null, "Europe/Paris").endsWith("· 08:30."), body("fr", null, "Europe/Paris"));
  }

  /** A row fanned out before the subject's zone was frozen reads in Paris, as every team was. */
  @Test
  void subjectWithoutAZone_readsInParis() {
    assertTrue(
        body("fr", "Europe/Paris", null).endsWith("· 08:30."), body("fr", "Europe/Paris", null));
    assertTrue(
        body("fr", "Asia/Tokyo", null).endsWith("· 08:30, heure de Paris (15:30 chez vous)."),
        body("fr", "Asia/Tokyo", null));
  }

  /** French elision and contraction come from the shared city naming. */
  @Test
  void zoneName_followsTheFrenchOfPhrase() {
    assertTrue(body("fr", "Europe/Paris", "Africa/Cairo").contains("heure du Caire ("));
    assertTrue(body("fr", "Europe/Paris", "Europe/Athens").contains("heure d'Athènes ("));
  }

  /** A team webhook: the team's zone is the reference, nobody's « chez vous ». */
  @Test
  void forTeam_namesTheZone_onlyWhenItIsNotTheTeams() {
    assertEquals(
        "dim. 20 sept. · 15:30",
        texts.formatRendezvous(
            RIDE, "fr", NotificationTexts.Zones.forTeam("Asia/Tokyo", "Asia/Tokyo")));
    assertEquals(
        "dim. 20 sept. · 15:30, heure de Tokyo",
        texts.formatRendezvous(
            RIDE, "fr", NotificationTexts.Zones.forTeam("Asia/Tokyo", "Europe/Paris")));
    // An old row, without the subject's zone: the team's.
    assertEquals(
        "dim. 20 sept. · 15:30",
        texts.formatRendezvous(RIDE, "fr", NotificationTexts.Zones.forTeam(null, "Asia/Tokyo")));
  }

  @Test
  void unknownLanguage_fallsBackToFrench() {
    assertEquals(
        "dim. 20 sept. · 08:30 : x",
        texts.render(message(NotificationType.RIDE_PUBLISHED, "de", "x")).title());
  }

  @Test
  void placeholdersInUserContent_areNotExpanded() {
    assertEquals(
        "dim. 20 sept. · 08:30 : {team}",
        texts.render(message(NotificationType.RIDE_PUBLISHED, null, "{team}")).subject());
  }

  @Test
  void links_pointAtTheCanonicalWebRoute() {
    assertEquals(
        "https://club.example/teams/club/rides/sortie",
        message(NotificationType.RIDE_PUBLISHED, null, "x").subjectUrl());
  }

  @Test
  void excerpt_isFlattenedAndCut() {
    String excerpt = NotificationRecipientResolver.excerpt("  a\n\n b " + "c".repeat(400));
    assertTrue(excerpt.startsWith("a b c"));
    assertEquals(NotificationRecipientResolver.EXCERPT_LENGTH, excerpt.length());
    assertTrue(excerpt.endsWith("…"));
  }
}

package fr.pedalons.service.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/** Plain unit test: no Quarkus, the texts are classpath files. */
class NotificationTextsTest {

  private final NotificationTexts texts = new NotificationTexts();

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
        Instant.parse("2026-09-20T06:30:00Z"),
        subjectTimezone,
        "8h30 au parking",
        "https://club.example",
        "Le Club",
        List.of());
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
    assertEquals("Nouvelle sortie : Col du Galibier", fr.subject());
    assertEquals(
        "Alice a publié la sortie « Col du Galibier », prévue le dimanche 20 septembre à 08h30.",
        fr.body());

    NotificationTexts.Rendered en =
        texts.render(message(NotificationType.RIDE_PUBLISHED, "en", "Col du Galibier"));
    assertEquals("New ride: Col du Galibier", en.subject());
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
    // 2026-09-20T06:30Z is 15h30 in Tokyo, 08h30 in Paris: same day.
    assertEquals(
        "La sortie « Col », à laquelle vous participez, part le dimanche 20 septembre à 15h30,"
            + " heure de Tokyo (08h30 chez vous).",
        body("fr", "Europe/Paris", "Asia/Tokyo"));
    assertEquals(
        "Sunday, September 20 at 3:30 PM, Tokyo time (8:30 AM your time)",
        texts.formatRendezvous(
            Instant.parse("2026-09-20T06:30:00Z"),
            "en",
            NotificationTexts.Zones.forReader("Asia/Tokyo", "Europe/Paris")));
  }

  /** The reader's equivalent carries the short day when it is another day for them. */
  @Test
  void readersEquivalent_carriesTheDay_whenItChanges() {
    // 2026-09-20T06:30Z is 23h30 the day before in Los Angeles.
    assertEquals(
        "dimanche 20 septembre à 15h30, heure de Tokyo (sam. 23h30 chez vous)",
        texts.formatRendezvous(
            Instant.parse("2026-09-20T06:30:00Z"),
            "fr",
            NotificationTexts.Zones.forReader("Asia/Tokyo", "America/Los_Angeles")));
    assertEquals(
        "Sunday, September 20 at 3:30 PM, Tokyo time (Sat 11:30 PM your time)",
        texts.formatRendezvous(
            Instant.parse("2026-09-20T06:30:00Z"),
            "en",
            NotificationTexts.Zones.forReader("Asia/Tokyo", "America/Los_Angeles")));
  }

  /** Offsets, not identifiers: a Paris ride read from Brussels says nothing more than today. */
  @Test
  void sameOffset_noMention() {
    assertTrue(
        body("fr", "Europe/Brussels", "Europe/Paris").endsWith("dimanche 20 septembre à 08h30."));
  }

  /** A reader in Paris is told about a ride in Paris read from Tokyo — in the ride's time. */
  @Test
  void readerAbroad_getsTheRidesTime_andTheirs() {
    assertTrue(
        body("fr", "Asia/Tokyo", "Europe/Paris")
            .endsWith("dimanche 20 septembre à 08h30, heure de Paris (15h30 chez vous)."),
        body("fr", "Asia/Tokyo", "Europe/Paris"));
  }

  /** No zone of their own: the zone is named against Paris, with no « chez vous ». */
  @Test
  void readerWithoutAZone_getsTheZoneNameOnly() {
    assertTrue(
        body("fr", null, "Asia/Tokyo").endsWith("à 15h30, heure de Tokyo."),
        body("fr", null, "Asia/Tokyo"));
    assertTrue(
        body("fr", null, "Europe/Paris").endsWith("à 08h30."), body("fr", null, "Europe/Paris"));
  }

  /** A row fanned out before the subject's zone was frozen reads in Paris, as every team was. */
  @Test
  void subjectWithoutAZone_readsInParis() {
    assertTrue(
        body("fr", "Europe/Paris", null).endsWith("à 08h30."), body("fr", "Europe/Paris", null));
    assertTrue(
        body("fr", "Asia/Tokyo", null).endsWith("à 08h30, heure de Paris (15h30 chez vous)."),
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
    Instant instant = Instant.parse("2026-09-20T06:30:00Z");
    assertEquals(
        "dimanche 20 septembre à 15h30",
        texts.formatRendezvous(
            instant, "fr", NotificationTexts.Zones.forTeam("Asia/Tokyo", "Asia/Tokyo")));
    assertEquals(
        "dimanche 20 septembre à 15h30, heure de Tokyo",
        texts.formatRendezvous(
            instant, "fr", NotificationTexts.Zones.forTeam("Asia/Tokyo", "Europe/Paris")));
    // An old row, without the subject's zone: the team's.
    assertEquals(
        "dimanche 20 septembre à 15h30",
        texts.formatRendezvous(instant, "fr", NotificationTexts.Zones.forTeam(null, "Asia/Tokyo")));
  }

  @Test
  void unknownLanguage_fallsBackToFrench() {
    assertEquals(
        "Nouvelle sortie dans Le Club",
        texts.render(message(NotificationType.RIDE_PUBLISHED, "de", "x")).title());
  }

  @Test
  void placeholdersInUserContent_areNotExpanded() {
    assertEquals(
        "Nouvelle sortie : {team}",
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

  /** The data-export mail's expiry reads like a notification date (API-92). */
  @Test
  void formatDateTime_followsTheReadersLanguageAndZone() {
    Instant instant = Instant.parse("2026-10-11T06:30:00Z");
    assertEquals(
        "dimanche 11 octobre à 08h30",
        NotificationTexts.formatDateTime(instant, "fr-FR", "Europe/Paris"));
    assertEquals(
        "Sunday, October 11 at 3:30 PM",
        NotificationTexts.formatDateTime(instant, "en", "Asia/Tokyo"));
    // No zone, or one nobody knows: Paris.
    assertEquals(
        "dimanche 11 octobre à 08h30",
        NotificationTexts.formatDateTime(instant, null, "Mars/Base"));
  }
}

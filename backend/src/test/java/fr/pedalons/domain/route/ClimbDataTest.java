package fr.pedalons.domain.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.dto.routes.response.ClimbDto;
import fr.pedalons.dto.routes.response.ClimbPartDto;
import fr.pedalons.enums.ClimbCategory;
import io.github.glandais.engine.climb.Climb;
import io.github.glandais.engine.climb.ClimbPart;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.hypersistence.utils.hibernate.type.util.ObjectMapperWrapper;
import java.lang.reflect.Type;
import java.util.List;
import org.hibernate.HibernateException;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * Locks the shape of {@code gpx_tracks.climbs} — arbitration 1 of the vcyclist migration.
 *
 * <p>The JSON fixture below is a {@code climbs} document in the form gpx2web produced: a
 * <b>bare JSON array</b> (its {@code Climbs}/{@code ClimbParts} were {@code ArrayList} subclasses)
 * of objects whose keys are the record components of {@code io.github.glandais.gpx.climb.Climb} and
 * {@code ClimbPart}, with grades in <b>percent</b> and part distances <b>relative to the climb
 * start</b>. Every route imported before the migration is stored exactly like this, and nothing
 * rewrites those rows.
 *
 * <p>Deserialization goes through {@link JsonConfiguration#INSTANCE}, i.e. the very
 * {@link ObjectMapperWrapper} {@code JsonBinaryType} hands to Hibernate for the {@code @Type}
 * annotated column, and through the generic type of the {@link GpxTrack#getClimbs()} field itself —
 * so this test reads the stored bytes the way production does, not the way a hand-rolled
 * {@code ObjectMapper} would.
 *
 * <p>Rename a component of {@link ClimbData} or {@link ClimbPartData} and this test fails: the old
 * key becomes an unknown property and every pre-migration route stops rendering its climbs.
 */
class ClimbDataTest {

  /** Exactly the mapper {@code JsonBinaryType} uses — see the class javadoc. */
  private static final ObjectMapperWrapper MAPPER =
      JsonConfiguration.INSTANCE.getObjectMapperWrapper();

  /** {@code List<ClimbData>}, read off the entity field rather than restated here. */
  private static final Type CLIMBS_TYPE = climbsFieldType();

  /**
   * One 7.4 km climb broken into three parts (up, false flat down, steep finish) followed by a
   * short bump with a single part. Written the way it sits in the column: numbers as doubles, keys
   * in gpx2web's order, no wrapper object.
   */
  private static final String STORED_CLIMBS =
      """
      [
        {
          "startDist": 12450.0,
          "startEle": 400.0,
          "endDist": 19870.0,
          "endEle": 960.0,
          "dist": 7420.0,
          "elevation": 560.0,
          "positiveElevation": 603.0,
          "negativeElevation": -43.0,
          "grade": 7.547169811320755,
          "climbingGrade": 12.206477732793522,
          "parts": [
            {
              "startDist": 0.0,
              "startEle": 400.0,
              "endDist": 2620.0,
              "endEle": 640.0,
              "dist": 2620.0,
              "ele": 240.0,
              "grade": 9.16030534351145
            },
            {
              "startDist": 2620.0,
              "startEle": 640.0,
              "endDist": 5100.0,
              "endEle": 597.0,
              "dist": 2480.0,
              "ele": -43.0,
              "grade": -1.7338709677419355
            },
            {
              "startDist": 5100.0,
              "startEle": 597.0,
              "endDist": 7420.0,
              "endEle": 960.0,
              "dist": 2320.0,
              "ele": 363.0,
              "grade": 15.646551724137931
            }
          ]
        },
        {
          "startDist": 24500.0,
          "startEle": 300.0,
          "endDist": 25000.0,
          "endEle": 340.0,
          "dist": 500.0,
          "elevation": 40.0,
          "positiveElevation": 40.0,
          "negativeElevation": 0.0,
          "grade": 8.0,
          "climbingGrade": 8.0,
          "parts": [
            {
              "startDist": 0.0,
              "startEle": 300.0,
              "endDist": 500.0,
              "endEle": 340.0,
              "dist": 500.0,
              "ele": 40.0,
              "grade": 8.0
            }
          ]
        }
      ]
      """;

  private static Type climbsFieldType() {
    try {
      return GpxTrack.class.getDeclaredField("climbs").getGenericType();
    } catch (NoSuchFieldException e) {
      throw new AssertionError("GpxTrack no longer maps the climbs column", e);
    }
  }

  private static List<ClimbData> read(String json) {
    return MAPPER.fromString(json, CLIMBS_TYPE);
  }

  @Nested
  class StoredDocuments {

    @Test
    void deserializeFieldForFieldThroughTheProductionMapper() {
      List<ClimbData> climbs = read(STORED_CLIMBS);

      assertEquals(2, climbs.size());
      ClimbData col = climbs.getFirst();
      assertEquals(12450.0, col.startDist());
      assertEquals(400.0, col.startEle());
      assertEquals(19870.0, col.endDist());
      assertEquals(960.0, col.endEle());
      assertEquals(7420.0, col.dist());
      assertEquals(560.0, col.elevation());
      assertEquals(603.0, col.positiveElevation());
      assertEquals(-43.0, col.negativeElevation());
      assertEquals(7.547169811320755, col.grade(), "grade is stored in percent, not as a ratio");
      assertEquals(12.206477732793522, col.climbingGrade());

      assertEquals(3, col.parts().size());
      ClimbPartData first = col.parts().getFirst();
      assertEquals(0.0, first.startDist(), "part distances are relative to the climb start");
      assertEquals(400.0, first.startEle());
      assertEquals(2620.0, first.endDist());
      assertEquals(640.0, first.endEle());
      assertEquals(2620.0, first.dist());
      assertEquals(240.0, first.ele(), "ele is the part's elevation gain, not an altitude");
      assertEquals(9.16030534351145, first.grade());

      ClimbPartData descending = col.parts().get(1);
      assertEquals(-43.0, descending.ele());
      assertEquals(-1.7338709677419355, descending.grade());
    }

    @Test
    void areRewrittenIdenticallyWhenTheEntityIsSavedBack() {
      // Hibernate rewrites the whole document on any update of the row: a field renamed only in
      // the writing direction would silently produce documents the deployed readers cannot parse.
      List<ClimbData> climbs = read(STORED_CLIMBS);

      assertEquals(MAPPER.toJsonNode(STORED_CLIMBS), MAPPER.toJsonNode(MAPPER.toString(climbs)));
    }

    @Test
    void withARenamedFieldFailLoudlyRatherThanSilentlyLosingIt() {
      // This is the failure mode the whole frozen-contract arbitration exists to prevent: it is
      // an exception on read, on every route imported before the migration.
      String renamed = STORED_CLIMBS.replace("\"startDist\"", "\"startDistance\"");

      assertThrows(HibernateException.class, () -> read(renamed));
    }
  }

  @Nested
  class DtoMapping {

    @Test
    void turnsAStoredClimbIntoTheSameDtoAsBeforeTheMigration() {
      ClimbDto dto = ClimbDto.from(read(STORED_CLIMBS).getFirst());

      assertEquals(12450, dto.startDistance());
      assertEquals(19870, dto.endDistance());
      assertEquals(603, dto.elevationGain(), "the DTO reports the summed ascent, not the net one");
      assertEquals(7.547169811320755, dto.averageGradient().doubleValue());
      assertEquals(
          15.646551724137931,
          dto.maxGradient().doubleValue(),
          "max gradient is the steepest part, the last one here");
      assertEquals(ClimbCategory.CAT2, dto.category());
    }

    @Test
    void shiftsPartDistancesBackToRouteAbsoluteMeters() {
      ClimbDto dto = ClimbDto.from(read(STORED_CLIMBS).getFirst());

      List<ClimbPartDto> parts = dto.parts();
      assertEquals(3, parts.size());
      assertEquals(12450, parts.getFirst().startDistance());
      assertEquals(15070, parts.getFirst().endDistance());
      assertEquals(240, parts.getFirst().elevationGain());
      assertEquals(9.16030534351145, parts.getFirst().grade().doubleValue());
      assertEquals(17550, parts.get(1).endDistance());
      assertEquals(
          dto.endDistance(),
          parts.getLast().endDistance(),
          "the last part must end where the climb ends");
    }

    @Test
    void categorizesTheShortBumpFromItsAscentAlone() {
      ClimbDto dto = ClimbDto.from(read(STORED_CLIMBS).get(1));

      assertEquals(ClimbCategory.CAT4, dto.category());
      assertEquals(
          8.0,
          dto.maxGradient().doubleValue(),
          "a single part means max gradient equals the average");
      assertEquals(24500, dto.parts().getFirst().startDistance());
    }
  }

  /**
   * The one place unit conversion happens. vcyclist reports grades as ratios and part distances as
   * absolute distances along the path; the stored contract wants percent and climb-relative.
   */
  @Nested
  class FromVcyclist {

    /**
     * 2 km climb starting 1 km into the path: +80 m, then a 20 m dip, then +100 m. Net gain 160 m
     * over 2000 m (8 %), 180 m of ascent over the 1500 m that actually go up (12 %).
     */
    private Climb sampleClimb() {
      return new Climb(
          10,
          40,
          1000.0,
          3000.0,
          100.0,
          260.0,
          180.0,
          -20.0,
          1500.0,
          List.of(
              new ClimbPart(1000.0, 2000.0, 100.0, 180.0),
              new ClimbPart(2000.0, 2500.0, 180.0, 160.0),
              new ClimbPart(2500.0, 3000.0, 160.0, 260.0)));
    }

    @Test
    void multipliesBothClimbGradesByAHundred() {
      ClimbData data = ClimbData.from(sampleClimb());

      assertEquals(8.0, data.grade(), 1e-9, "averageGrade is a ratio, the column holds percent");
      assertEquals(12.0, data.climbingGrade(), 1e-9);
    }

    @Test
    void keepsClimbDistancesAndElevationsAbsolute() {
      ClimbData data = ClimbData.from(sampleClimb());

      assertEquals(1000.0, data.startDist());
      assertEquals(3000.0, data.endDist());
      assertEquals(100.0, data.startEle());
      assertEquals(260.0, data.endEle());
      assertEquals(2000.0, data.dist());
      assertEquals(160.0, data.elevation(), "elevation is the net gain, as gpx2web stored it");
      assertEquals(180.0, data.positiveElevation());
      assertEquals(-20.0, data.negativeElevation());
    }

    @Test
    void rebasesPartDistancesOntoTheClimbStart() {
      List<ClimbPartData> parts = ClimbData.from(sampleClimb()).parts();

      assertEquals(3, parts.size());
      assertEquals(0.0, parts.getFirst().startDist(), "the first part starts at the climb start");
      assertEquals(1000.0, parts.getFirst().endDist());
      assertEquals(1000.0, parts.get(1).startDist());
      assertEquals(1500.0, parts.get(1).endDist());
      assertEquals(1500.0, parts.getLast().startDist());
      assertEquals(2000.0, parts.getLast().endDist(), "the last part ends at the climb length");
    }

    @Test
    void multipliesPartGradesByAHundredAndKeepsTheirSign() {
      List<ClimbPartData> parts = ClimbData.from(sampleClimb()).parts();

      assertEquals(8.0, parts.getFirst().grade(), 1e-9);
      assertEquals(-4.0, parts.get(1).grade(), 1e-9, "a dip inside a climb stays negative");
      assertEquals(20.0, parts.getLast().grade(), 1e-9);
      assertEquals(80.0, parts.getFirst().ele(), "ele is elevationGainM, not an altitude");
      assertEquals(-20.0, parts.get(1).ele());
      assertEquals(180.0, parts.get(1).startEle(), "elevations stay absolute, unlike distances");
      assertEquals(160.0, parts.get(1).endEle(), "elevations stay absolute, unlike distances");
    }

    @Test
    void roundTripsThroughTheDtoBackToVcyclistAbsoluteDistances() {
      // ClimbData.from subtracts the climb start, ClimbPartDto.from adds it back: the two shifts
      // must remain exact inverses or every rendered part drifts by the climb's own offset.
      Climb climb = sampleClimb();
      ClimbDto dto = ClimbDto.from(ClimbData.from(climb));

      for (int i = 0; i < climb.getParts().size(); i++) {
        ClimbPart source = climb.getParts().get(i);
        assertEquals(
            (int) Math.round(source.getStartDistanceM()), dto.parts().get(i).startDistance());
        assertEquals((int) Math.round(source.getEndDistanceM()), dto.parts().get(i).endDistance());
      }
    }

    @Test
    void handlesAClimbWithoutParts() {
      // ClimbDetector cannot currently produce one, but the column can hold one (a route stored
      // by an older gpx2web), and ClimbDto.getMaxGrade falls back to the climb grade.
      Climb bare = new Climb(0, 5, 0.0, 500.0, 100.0, 140.0, 40.0, 0.0, 0.0, List.of());

      ClimbData data = ClimbData.from(bare);
      assertTrue(data.parts().isEmpty());
      assertEquals(8.0, data.grade(), 1e-9);
      assertEquals(0.0, data.climbingGrade(), "no rising distance means no climbing grade");
      assertEquals(8.0, ClimbDto.from(data).maxGradient().doubleValue(), 1e-9);
    }
  }
}

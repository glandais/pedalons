package fr.pedalons.infrastructure.gps;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.gpx.CoursePoint;
import fr.pedalons.infrastructure.gpx.WaypointFormats;
import jakarta.enterprise.context.ApplicationScoped;
import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.jspecify.annotations.Nullable;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

/**
 * Converts GPX files to Garmin Connect course JSON format — the Courses API's {@code GeoPoint} is
 * {@code latitude}/{@code longitude}/{@code elevation}, the same over OAuth 1.0a and 2.0.
 */
@ApplicationScoped
public class GarminCourseConverter {

  /**
   * Convert GPX content to Garmin course JSON.
   *
   * @param gpxContent GPX file content
   * @param courseName Name for the course
   * @return JSON string for Garmin course API
   */
  public String convertToGarminCourse(byte[] gpxContent, String courseName) {
    return convertToGarminCourse(gpxContent, courseName, List.of());
  }

  /**
   * As {@link #convertToGarminCourse(byte[], String)}, with the course points of the route
   * (docs/LEDGER_*.md WEB-100, C3c): each one is a geo point inserted at its distance along the
   * track, interpolated between the two points around it, with an {@code information} object.
   * Distances are cumulated without a jump from one {@code <trk>} to the next, as the FIT does.
   */
  public String convertToGarminCourse(
      byte[] gpxContent, String courseName, List<CoursePoint> coursePoints) {
    try {
      DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
      factory.setNamespaceAware(true);
      // No DOCTYPE, hence no external entity nor entity expansion. The input is GPX we wrote
      // ourselves, but this parser must stay safe if that ever changes (docs/LEDGER_*.md SEC-14).
      factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
      factory.setXIncludeAware(false);
      factory.setExpandEntityReferences(false);
      DocumentBuilder builder = factory.newDocumentBuilder();
      Document doc = builder.parse(new ByteArrayInputStream(gpxContent));

      List<GeoPoint> geoPoints = new ArrayList<>();
      List<Double> cumulative = new ArrayList<>();
      org.w3c.dom.Node previousParent = null;
      double totalDistance = 0;
      double elevationGain = 0;
      double elevationLoss = 0;
      double prevLat = 0, prevLon = 0, prevEle = 0;
      boolean first = true;

      // Try track points first (trk/trkseg/trkpt)
      NodeList trkpts = doc.getElementsByTagName("trkpt");
      if (trkpts.getLength() == 0) {
        // Fall back to route points (rte/rtept)
        trkpts = doc.getElementsByTagName("rtept");
      }

      for (int i = 0; i < trkpts.getLength(); i++) {
        Element pt = (Element) trkpts.item(i);
        double lat = Double.parseDouble(pt.getAttribute("lat"));
        double lon = Double.parseDouble(pt.getAttribute("lon"));

        // Get elevation if present
        Double ele = null;
        NodeList eleNodes = pt.getElementsByTagName("ele");
        if (eleNodes.getLength() > 0) {
          ele = Double.parseDouble(eleNodes.item(0).getTextContent());
        }

        geoPoints.add(new GeoPoint(lat, lon, ele, null, null, null));

        // A new <trk> restarts the chain: no distance across the gap between two tracks
        org.w3c.dom.Node parent =
            pt.getParentNode() == null ? null : pt.getParentNode().getParentNode();
        if (parent != previousParent) {
          first = true;
          previousParent = parent;
        }
        if (!first) {
          totalDistance += haversineDistance(prevLat, prevLon, lat, lon);
          if (ele != null && prevEle != 0) {
            double eleDiff = ele - prevEle;
            if (eleDiff > 0) {
              elevationGain += eleDiff;
            } else {
              elevationLoss += Math.abs(eleDiff);
            }
          }
        }

        cumulative.add(totalDistance);
        prevLat = lat;
        prevLon = lon;
        prevEle = ele != null ? ele : 0;
        first = false;
      }

      return buildJsonCourse(
          courseName,
          totalDistance,
          elevationGain,
          elevationLoss,
          withCoursePoints(geoPoints, cumulative, coursePoints));
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  private String buildJsonCourse(
      String courseName,
      double distance,
      double elevationGain,
      double elevationLoss,
      List<GeoPoint> geoPoints) {
    StringBuilder json = new StringBuilder();
    json.append("{");
    json.append("\"courseName\":").append(jsonString(courseName)).append(",");
    json.append("\"distance\":").append(Math.round(distance)).append(",");
    json.append("\"elevationGain\":").append(Math.round(elevationGain)).append(",");
    json.append("\"elevationLoss\":").append(Math.round(elevationLoss)).append(",");
    json.append("\"activityType\":\"ROAD_CYCLING\",");
    json.append("\"coordinateSystem\":\"WGS84\",");
    json.append("\"geoPoints\":[");

    for (int i = 0; i < geoPoints.size(); i++) {
      if (i > 0) json.append(",");
      GeoPoint p = geoPoints.get(i);
      json.append("{\"latitude\":").append(p.lat).append(",\"longitude\":").append(p.lon);
      if (p.altitude != null) {
        json.append(",\"elevation\":").append(p.altitude);
      }
      if (p.information != null) {
        json.append(",\"distance\":").append(Math.round(p.distance * 10) / 10.0);
        json.append(",\"information\":{\"name\":")
            .append(jsonString(p.information))
            .append(",\"coursePointType\":")
            .append(jsonString(p.coursePointType))
            .append("}");
      }
      json.append("}");
    }

    json.append("]}");
    return json.toString();
  }

  /**
   * The track points with the course points inserted at their distance: after the last point
   * whose cumulative distance does not exceed it, at the position interpolated between that point
   * and the next. Before the first point for a distance of zero or less, after the last for one
   * past the end.
   */
  private List<GeoPoint> withCoursePoints(
      List<GeoPoint> points, List<Double> cumulative, List<CoursePoint> coursePoints) {
    if (coursePoints.isEmpty() || points.isEmpty()) {
      return points;
    }
    int n = points.size();
    List<List<GeoPoint>> after = new ArrayList<>(n + 1);
    for (int i = 0; i <= n; i++) {
      after.add(new ArrayList<>());
    }
    List<CoursePoint> sorted =
        coursePoints.stream().sorted(Comparator.comparingDouble(CoursePoint::distanceM)).toList();
    for (CoursePoint cp : sorted) {
      double d = cp.distanceM();
      int k = -1;
      for (int i = 0; i < n; i++) {
        if (cumulative.get(i) <= d) {
          k = i;
        } else {
          break;
        }
      }
      GeoPoint base;
      if (k < 0) {
        base = points.getFirst();
      } else if (k == n - 1) {
        base = points.get(n - 1);
      } else {
        GeoPoint a = points.get(k);
        GeoPoint b = points.get(k + 1);
        double span = cumulative.get(k + 1) - cumulative.get(k);
        double t = span <= 0 ? 0 : (d - cumulative.get(k)) / span;
        Double ele =
            a.altitude != null && b.altitude != null
                ? a.altitude + t * (b.altitude - a.altitude)
                : a.altitude;
        base =
            new GeoPoint(
                a.lat + t * (b.lat - a.lat), a.lon + t * (b.lon - a.lon), ele, null, null, null);
      }
      after
          .get(k + 1)
          .add(
              new GeoPoint(
                  base.lat,
                  base.lon,
                  base.altitude,
                  Math.max(0, d),
                  cp.name(),
                  WaypointFormats.courseApiType(cp.type())));
    }
    List<GeoPoint> result = new ArrayList<>(n + coursePoints.size());
    result.addAll(after.get(0));
    for (int i = 0; i < n; i++) {
      result.add(points.get(i));
      result.addAll(after.get(i + 1));
    }
    return result;
  }

  private String jsonString(String value) {
    return "\""
        + value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
        + "\"";
  }

  /**
   * Calculate distance between two points using Haversine formula.
   *
   * @return Distance in meters
   */
  private double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    double R = 6371000; // Earth radius in meters
    double dLat = Math.toRadians(lat2 - lat1);
    double dLon = Math.toRadians(lon2 - lon1);
    double a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2)
                * Math.sin(dLon / 2);
    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /** A point of the course; {@code information} is set on a course point only. */
  private record GeoPoint(
      double lat,
      double lon,
      @Nullable Double altitude,
      @Nullable Double distance,
      @Nullable String information,
      @Nullable String coursePointType) {}
}

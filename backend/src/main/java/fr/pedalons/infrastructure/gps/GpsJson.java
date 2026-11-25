package fr.pedalons.infrastructure.gps;

import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;

/**
 * Fields of the GPS services' JSON answers, read as Jackson 2 did. Jackson 3's {@code asString()}
 * throws on an object or an array, and its {@code canConvertToLong()} is false for 3.7; here a
 * container is absent and a fractional number is truncated (docs/LEDGER_*.md API-220).
 */
final class GpsJson {
  private GpsJson() {}

  /** A scalar as text, or null when absent, null or a container. */
  static @Nullable String string(JsonNode root, String key) {
    JsonNode node = root.path(key);
    return node.isValueNode() && !node.isNull() ? node.asString() : null;
  }

  /** A number, or a numeric string ({@code "3600"}, some providers send one), else null. */
  static @Nullable Long longValue(JsonNode root, String key) {
    JsonNode node = root.path(key);
    if (node.canConvertToLong()) {
      return node.asLong();
    }
    if (node.isNumber()) {
      // fractional, or beyond a long: truncated like Jackson 2's asLong()
      return (long) node.asDouble();
    }
    if (!node.isString()) {
      return null;
    }
    try {
      return Long.parseLong(node.asString().trim());
    } catch (NumberFormatException e) {
      return null;
    }
  }
}

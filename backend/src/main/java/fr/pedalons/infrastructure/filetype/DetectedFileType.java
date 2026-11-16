package fr.pedalons.infrastructure.filetype;

import java.util.Objects;

/**
 * Result of running Magika (plus filename fallback) on an uploaded file.
 *
 * @param label Magika label (e.g. {@code png}, {@code jpeg}, {@code xml}, {@code gpx}, {@code fit}),
 *     never null
 * @param modelLabel what the model itself read, before Magika replaced a low-confidence answer by
 *     {@code txt} or {@code unknown}, or one of its own catch-alls by its overwrite map ({@code
 *     randomtxt} → {@code txt}); equal to {@code label} when nothing was replaced. A blocklist
 *     refuses it as well as the label (docs/LEDGER_*.md SEC-53). Never null
 * @param confidence model probability in [0, 1]; retained on the record so callers can log/inspect
 *     it for diagnostics even though the validation pipeline currently makes accept/reject
 *     decisions on {@code label} alone
 * @param mimeType resolved MIME type, never null; prefers filename-based hints for gpx/fit where
 *     Magika reports a generic container label (xml / unknown)
 */
public record DetectedFileType(String label, String modelLabel, float confidence, String mimeType) {

  public DetectedFileType {
    Objects.requireNonNull(label, "label");
    Objects.requireNonNull(modelLabel, "modelLabel");
    Objects.requireNonNull(mimeType, "mimeType");
    if (confidence < 0f || confidence > 1f || Float.isNaN(confidence)) {
      throw new IllegalArgumentException("confidence must be in [0, 1], got " + confidence);
    }
  }
}

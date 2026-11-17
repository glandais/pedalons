package fr.pedalons.infrastructure.filetype;

import edu.kit.kastel.mcse.ardoco.magika.FileTypePredictor;
import edu.kit.kastel.mcse.ardoco.magika.Prediction;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.image.ImageFormat;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Content-type detection backed by Google Magika (ArDoCo Java port). The predictor loads an ONNX
 * model on startup and is safe to share across threads; sessions are opened per call by the
 * underlying library.
 *
 * <p>Magika returns coarse labels (e.g. {@code xml}, {@code unknown}). For formats where the
 * filename carries signal that Magika does not (GPX under XML, FIT as generic binary) we prefer the
 * extension-based MIME type.
 *
 * <p><strong>Concurrency / performance:</strong> the upstream {@code FileTypePredictor} creates a
 * fresh ONNX Runtime session per {@code predictFileType} call, which dominates the cost of
 * detection (model load + tensor allocation) and serializes naturally on the underlying ORT
 * environment. Under bursty concurrent uploads this becomes the bottleneck before any I/O does. If
 * upload throughput becomes an issue, options include (a) wrapping the predictor in a small worker
 * pool with cached ORT sessions, (b) bumping ORT thread settings, or (c) replacing this dependency
 * with a thin direct ORT integration that reuses a single session across requests.
 */
@ApplicationScoped
public class FileTypeDetector {

  private static final Logger LOG = Logger.getLogger(FileTypeDetector.class);

  private static final Map<String, String> LABEL_TO_MIME =
      Map.ofEntries(
          Map.entry("png", "image/png"),
          Map.entry("jpeg", "image/jpeg"),
          Map.entry("gif", "image/gif"),
          Map.entry("webp", "image/webp"),
          Map.entry("bmp", "image/bmp"),
          Map.entry("tiff", "image/tiff"),
          Map.entry("ico", "image/x-icon"),
          Map.entry("svg", "image/svg+xml"),
          Map.entry("pdf", "application/pdf"),
          Map.entry("xml", "application/xml"),
          Map.entry("gpx", "application/gpx+xml"),
          Map.entry("fit", "application/vnd.ant.fit"),
          Map.entry("json", "application/json"),
          Map.entry("html", "text/html"),
          Map.entry("txt", "text/plain"),
          Map.entry("csv", "text/csv"),
          Map.entry("zip", "application/zip"));

  private FileTypePredictor predictor;

  @PostConstruct
  void init() {
    try {
      this.predictor = new FileTypePredictor();
      LOG.info("Magika FileTypePredictor initialized successfully");
    } catch (Exception e) {
      LOG.error("Failed to initialize Magika FileTypePredictor", e);
      throw e;
    }
  }

  /** Runs Magika against {@code file} and returns a label + confidence + resolved MIME. */
  public DetectedFileType detect(File file, @Nullable String fileName) {
    Prediction prediction;
    try {
      prediction = predictor.predictFileType(file.toPath());
    } catch (Exception e) {
      LOG.errorf(
          e, "Magika file type detection failed fileName=%s path=%s", fileName, file.toPath());
      throw new BadRequestException(ErrorCode.FILE_DETECTION_FAILED, e);
    }
    String label = prediction.label();
    String modelLabel = modelLabel(prediction);
    String mime = resolveMime(label, fileName);
    LOG.debugf(
        "Magika detected label=%s modelLabel=%s confidence=%.3f mime=%s for file=%s",
        label, modelLabel, prediction.probability(), mime, fileName);
    return new DetectedFileType(label, modelLabel, prediction.probability(), mime);
  }

  /**
   * The model's own reading, kept apart from the label Magika may have replaced by {@code txt} or
   * {@code unknown}; the label itself when Magika gives none (a file too small for the model).
   */
  private static String modelLabel(Prediction prediction) {
    String dlLabel = prediction.dlLabel();
    return dlLabel == null || dlLabel.isBlank() || Prediction.UNDEFINED.equals(dlLabel)
        ? prediction.label()
        : dlLabel;
  }

  /**
   * Detects the file type and validates it against the category derived from {@code assetType}.
   *
   * <p>Acceptance has two stages: first the Magika label must satisfy the category policy (an
   * allowlist for IMAGE/GPX/FIT, a blocklist for ATTACHMENT — see {@link FileTypeCategory}); if
   * the label check fails, a filename-extension fallback is consulted (see {@link
   * #matchesByExtension}) which covers small/empty GPX and FIT files where Magika cannot reach a
   * confident decision. When the extension fallback is the deciding factor a WARN is logged so a
   * silent Magika regression is still visible.
   *
   * <p>Throws {@link BadRequestException} with {@link ErrorCode#FILE_TYPE_REJECTED} when neither
   * the label policy nor the extension fallback accepts the file, or {@link
   * ErrorCode#FILE_DETECTION_FAILED} when Magika itself errors out (see {@link #detect}).
   */
  public DetectedFileType detectAndValidate(
      File file, @Nullable String fileName, AssetType assetType) {
    FileTypeCategory category = FileTypeCategory.forAssetType(assetType);
    DetectedFileType image = detectImage(file, fileName, assetType, category);
    if (image != null) {
      return image;
    }
    refuseVideo(file, fileName, assetType, category);
    DetectedFileType detected = detect(file, fileName);
    refuseActiveDocument(detected, fileName, assetType, category);
    boolean acceptedByLabel = category.accepts(detected.label(), detected.modelLabel());
    if (!acceptedByLabel) {
      if (!matchesByExtension(category, fileName, detected.label())) {
        LOG.warnf(
            "Rejecting upload fileName=%s assetType=%s detectedLabel=%s modelLabel=%s category=%s"
                + " %s=%s",
            fileName,
            assetType,
            detected.label(),
            detected.modelLabel(),
            category,
            policyKey(category),
            category.getLabels());
        throw new BadRequestException(ErrorCode.FILE_TYPE_REJECTED);
      }
      LOG.warnf(
          "Accepting upload via extension fallback (Magika label rejected by category policy):"
              + " fileName=%s assetType=%s detectedLabel=%s confidence=%.3f category=%s %s=%s",
          fileName,
          assetType,
          detected.label(),
          detected.confidence(),
          category,
          policyKey(category),
          category.getLabels());
    }
    return detected;
  }

  /**
   * Decides on an image by its first bytes, before Magika, which has no label for HEIC, AVIF or
   * JPEG XL. An image storage re-encodes is accepted where images are ({@link
   * FileTypeCategory#IMAGE}, {@link FileTypeCategory#ATTACHMENT}), with the content type it will be
   * stored under: re-encoding leaves nothing of the uploaded bytes, so Magika has nothing to guard
   * against. Elsewhere (GPX, FIT), Magika and the file name decide as for any other file. A JPEG
   * 2000, which cannot be re-encoded, is refused whatever the category. docs/LEDGER_*.md API-43.
   *
   * @return the detected image, or {@code null} for anything else, to let Magika decide
   */
  private static @Nullable DetectedFileType detectImage(
      File file, @Nullable String fileName, AssetType assetType, FileTypeCategory category) {
    ImageFormat format;
    try {
      format = ImageFormat.sniff(file.toPath());
    } catch (IOException e) {
      throw new BadRequestException(ErrorCode.FILE_DETECTION_FAILED, e);
    }
    if (format.isRefused()) {
      LOG.warnf(
          "Rejecting upload fileName=%s assetType=%s: %s image, it cannot be re-encoded",
          fileName, assetType, format);
      throw new BadRequestException(ErrorCode.FILE_TYPE_REJECTED);
    }
    if (!format.isReencoded()
        || (category != FileTypeCategory.IMAGE && category != FileTypeCategory.ATTACHMENT)) {
      return null;
    }
    String label = format.name().toLowerCase(Locale.ROOT);
    return new DetectedFileType(label, label, 1f, format.storedMimeType());
  }

  /**
   * The content types a browser renders as a document that can run script, refused in images and
   * attachments whatever label Magika gave: a small SVG it reads as {@code txt} would otherwise be
   * stored as {@code image/svg+xml} on the strength of its file name (docs/LEDGER_*.md SEC-1).
   */
  private static final Set<String> ACTIVE_DOCUMENT_TYPES =
      Set.of("image/svg+xml", "application/xml", "text/xml", "text/html", "application/xhtml+xml");

  private static void refuseActiveDocument(
      DetectedFileType detected,
      @Nullable String fileName,
      AssetType assetType,
      FileTypeCategory category) {
    if ((category == FileTypeCategory.IMAGE || category == FileTypeCategory.ATTACHMENT)
        && ACTIVE_DOCUMENT_TYPES.contains(detected.mimeType())) {
      LOG.warnf(
          "Rejecting upload fileName=%s assetType=%s: served as %s, a document that can run script",
          fileName, assetType, detected.mimeType());
      throw new BadRequestException(ErrorCode.FILE_TYPE_REJECTED);
    }
  }

  /**
   * A video container read from its first bytes, refused in images and attachments whatever label
   * Magika gives it: a recording carries where it was made, in boxes and in timed GPS tracks that
   * cleaning cannot reach (docs/LEDGER_*.md API-46). An ISO base media file ({@code ftyp}) gets
   * here only when it is not a still image — {@link ImageFormat} took HEIF and AVIF before —, so
   * MP4, MOV and 3GP are refused, and the M4A audio built on the same container with them. Then
   * Matroska and WebM (EBML), AVI and FLV.
   */
  private static void refuseVideo(
      File file, @Nullable String fileName, AssetType assetType, FileTypeCategory category) {
    if (category != FileTypeCategory.IMAGE && category != FileTypeCategory.ATTACHMENT) {
      return;
    }
    byte[] head;
    try (InputStream in = Files.newInputStream(file.toPath())) {
      head = in.readNBytes(12);
    } catch (IOException e) {
      throw new BadRequestException(ErrorCode.FILE_DETECTION_FAILED, e);
    }
    if (isVideoContainer(head)) {
      LOG.warnf("Rejecting upload fileName=%s assetType=%s: a video", fileName, assetType);
      throw new BadRequestException(ErrorCode.FILE_TYPE_REJECTED);
    }
  }

  static boolean isVideoContainer(byte[] head) {
    int n = head.length;
    boolean isoBaseMedia = n >= 8 && ascii(head, 4, 4).equals("ftyp");
    boolean ebml =
        n >= 4
            && (head[0] & 0xFF) == 0x1A
            && (head[1] & 0xFF) == 0x45
            && (head[2] & 0xFF) == 0xDF
            && (head[3] & 0xFF) == 0xA3;
    boolean avi = n >= 12 && ascii(head, 0, 4).equals("RIFF") && ascii(head, 8, 4).equals("AVI ");
    boolean flv = n >= 3 && ascii(head, 0, 3).equals("FLV");
    return isoBaseMedia || ebml || avi || flv;
  }

  private static String ascii(byte[] b, int offset, int length) {
    return new String(b, offset, length, StandardCharsets.ISO_8859_1);
  }

  private static String policyKey(FileTypeCategory category) {
    return category.isExcludeMode() ? "excluded" : "allowed";
  }

  private static String resolveMime(String label, @Nullable String fileName) {
    String extensionMime = mimeFromExtension(fileName);
    if (extensionMime != null
        && ("xml".equals(label)
            || "unknown".equals(label)
            || "empty".equals(label)
            || "txt".equals(label))) {
      return extensionMime;
    }
    String mapped = LABEL_TO_MIME.get(label);
    if (mapped != null) {
      return mapped;
    }
    return extensionMime != null ? extensionMime : "application/octet-stream";
  }

  private static @Nullable String mimeFromExtension(@Nullable String fileName) {
    if (fileName == null) {
      return null;
    }
    String lower = fileName.toLowerCase(Locale.ROOT);
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
    if (lower.endsWith(".gif")) return "image/gif";
    if (lower.endsWith(".webp")) return "image/webp";
    if (lower.endsWith(".svg")) return "image/svg+xml";
    if (lower.endsWith(".gpx")) return "application/gpx+xml";
    if (lower.endsWith(".fit")) return "application/vnd.ant.fit";
    if (lower.endsWith(".pdf")) return "application/pdf";
    if (lower.endsWith(".xml")) return "application/xml";
    if (lower.endsWith(".json")) return "application/json";
    return null;
  }

  private static boolean matchesByExtension(
      FileTypeCategory category, @Nullable String fileName, String label) {
    if (fileName == null) {
      return false;
    }
    String lower = fileName.toLowerCase(Locale.ROOT);
    return switch (category) {
      case GPX -> lower.endsWith(".gpx");
      case FIT -> lower.endsWith(".fit");
      // An attached GPX: the xml label ATTACHMENT refuses, let through on its name only. It is
      // stored as application/gpx+xml after TrackAttachmentSanitizer rewrote it from its tracks —
      // nothing else of the upload survives (docs/LEDGER_*.md SEC-1, API-49).
      // An attached FIT likewise: Magika has no FIT label and answers `unknown`, which ATTACHMENT
      // refuses (since magika 0.7.0, docs/LEDGER_*.md SEC-53). Stored as application/vnd.ant.fit,
      // it is decoded and rewritten as a course by TrackAttachmentSanitizer — refused if it does
      // not decode (API-55).
      case ATTACHMENT ->
          ("xml".equals(label) && lower.endsWith(".gpx"))
              || ("unknown".equals(label) && lower.endsWith(".fit"));
      case IMAGE -> false;
    };
  }
}

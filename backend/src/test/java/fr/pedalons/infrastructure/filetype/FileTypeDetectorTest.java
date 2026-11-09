package fr.pedalons.infrastructure.filetype;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Set;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

@QuarkusTest
class FileTypeDetectorTest extends AbstractBaseTest {

  @Inject FileTypeDetector detector;

  @TempDir Path tempDir;

  private File pngFile() {
    return new File("src/test/resources/image.png");
  }

  private File gpxFile() {
    return new File("src/test/resources/example.gpx");
  }

  private File emptyGpxFile() {
    return new File("src/test/resources/empty.gpx");
  }

  private File writeText(String name, String content) throws IOException {
    Path path = tempDir.resolve(name);
    Files.writeString(path, content, StandardCharsets.UTF_8);
    return path.toFile();
  }

  @Nested
  class ResolveMime {

    @Test
    void pngReturnsImagePngMime() {
      DetectedFileType detected = detector.detect(pngFile(), "image.png");
      assertEquals("png", detected.label());
      assertEquals("image/png", detected.mimeType());
    }

    @Test
    void xmlLabelWithGpxExtensionPrefersGpxMime() {
      DetectedFileType detected = detector.detect(gpxFile(), "example.gpx");
      assertEquals("application/gpx+xml", detected.mimeType());
      assertTrue(
          Set.of("xml", "gpx", "txt").contains(detected.label()),
          "expected text-like label, got " + detected.label());
    }

    @Test
    void xmlLabelWithXmlExtensionPrefersXmlMime() {
      DetectedFileType detected = detector.detect(gpxFile(), "renamed.xml");
      assertEquals("application/xml", detected.mimeType());
    }

    @Test
    void txtLabelWithJsonExtensionPrefersJsonMime() throws IOException {
      File textFile =
          writeText(
              "data.json",
              "This is plain text content long enough for Magika to classify it as txt"
                  + " rather than something more specific.");
      DetectedFileType detected = detector.detect(textFile, "data.json");
      assertEquals("application/json", detected.mimeType());
    }

    @Test
    void emptyLabelFallsBackToExtensionMime() throws IOException {
      File empty = writeText("blank.gpx", "");
      DetectedFileType detected = detector.detect(empty, "blank.gpx");
      assertEquals("application/gpx+xml", detected.mimeType());
    }

    @Test
    void unmappedLabelWithoutExtensionReturnsOctetStream() throws IOException {
      File noExt = writeText("noext", "");
      DetectedFileType detected = detector.detect(noExt, null);
      assertEquals("application/octet-stream", detected.mimeType());
    }
  }

  @Nested
  class MatchesByExtensionFallback {

    @Test
    void gpxExtensionRescuesNonAllowlistLabel() {
      assertDoesNotThrow(
          () -> detector.detectAndValidate(pngFile(), "tricky.gpx", AssetType.ROUTE_ORIGINAL_GPX),
          "extension fallback should accept .gpx filename even when Magika returns a non-allowlist"
              + " label like png");
    }

    @Test
    void fitExtensionRescuesNonAllowlistLabel() {
      assertDoesNotThrow(
          () -> detector.detectAndValidate(pngFile(), "tricky.fit", AssetType.ROUTE_FIT),
          "extension fallback should accept .fit filename even when Magika returns a non-allowlist"
              + " label like png");
    }

    @Test
    void noExtensionFallbackForImageCategory() {
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () -> detector.detectAndValidate(gpxFile(), "evil.png", AssetType.IMAGE));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }

    @Test
    void noExtensionFallbackForAttachmentCategory() throws IOException {
      File htmlFile =
          writeText(
              "evil.html",
              "<!DOCTYPE html>\n<html><head><title>X</title></head>"
                  + "<body><h1>Hello</h1><p>Long enough html content for Magika to detect"
                  + " the html type reliably.</p><script>alert('xss');</script></body></html>");
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () -> detector.detectAndValidate(htmlFile, "evil.html", AssetType.ATTACHMENT));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }
  }

  /** docs/LEDGER_*.md SEC-1: nothing a browser renders as a scripted document is stored. */
  @Nested
  class ActiveDocuments {

    private static final String SVG =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            + "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\""
            + " viewBox=\"0 0 100 100\">\n"
            + "  <rect x=\"10\" y=\"10\" width=\"80\" height=\"80\" fill=\"#228be6\"/>\n"
            + "  <circle cx=\"50\" cy=\"50\" r=\"30\" fill=\"#ffffff\"/>\n"
            + "</svg>\n";

    @Test
    void refusesAnSvgAsAnImageOrAnAttachment() throws IOException {
      File svg = writeText("logo.svg", SVG);
      for (AssetType type : new AssetType[] {AssetType.IMAGE, AssetType.ATTACHMENT}) {
        PedalonsException ex =
            assertThrows(
                PedalonsException.class,
                () -> detector.detectAndValidate(svg, "logo.svg", type),
                type.name());
        assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode(), type.name());
      }
    }

    @Test
    void refusesATinySvgMagikaReadsAsText() throws IOException {
      // Too short for a confident label: its name alone would make it image/svg+xml
      File svg = writeText("dot.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\"/>");
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () -> detector.detectAndValidate(svg, "dot.svg", AssetType.ATTACHMENT));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }

    @Test
    void refusesAnXmlAttachment() throws IOException {
      File xml =
          writeText(
              "data.xml",
              "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<catalog>\n"
                  + "  <book id=\"b1\"><title>Le Tour</title><year>1903</year></book>\n"
                  + "  <book id=\"b2\"><title>Paris-Roubaix</title><year>1896</year></book>\n"
                  + "</catalog>\n");
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () -> detector.detectAndValidate(xml, "data.xml", AssetType.ATTACHMENT));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }

    @Test
    void stillAcceptsAnAttachedGpx() {
      // Labelled xml, let through on its name: API-49 rewrites it from its tracks before storing
      DetectedFileType detected =
          detector.detectAndValidate(gpxFile(), "example.gpx", AssetType.ATTACHMENT);
      assertEquals("application/gpx+xml", detected.mimeType());
    }
  }

  /** docs/LEDGER_*.md API-46: a video is refused by its container, whatever Magika says. */
  @Nested
  class Videos {

    private File writeBytes(String name, byte[] head) throws IOException {
      byte[] content = java.util.Arrays.copyOf(head, 4096);
      for (int i = head.length; i < content.length; i++) {
        content[i] = (byte) (i * 31);
      }
      Path path = tempDir.resolve(name);
      Files.write(path, content);
      return path.toFile();
    }

    private void assertRefused(File file, String name) {
      for (AssetType type : new AssetType[] {AssetType.IMAGE, AssetType.ATTACHMENT}) {
        PedalonsException ex =
            assertThrows(
                PedalonsException.class,
                () -> detector.detectAndValidate(file, name, type),
                name + " as " + type);
        assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode(), name + " as " + type);
      }
    }

    @Test
    void refusesAnMp4AMovAnd3gp() throws IOException {
      assertRefused(
          writeBytes("ride.mp4", ascii("\0\0\0\u0020ftypisom\0\0\u0002\0isomiso2mp41")),
          "ride.mp4");
      assertRefused(
          writeBytes("IMG_0001.MOV", ascii("\0\0\0\u0014ftypqt  \0\0\0\0qt  ")), "IMG_0001.MOV");
      assertRefused(writeBytes("clip.3gp", ascii("\0\0\0\u0018ftyp3gp4\0\0\0\0")), "clip.3gp");
    }

    @Test
    void refusesAWebmAnAviAndAnFlv() throws IOException {
      assertRefused(
          writeBytes("clip.webm", new byte[] {0x1A, 0x45, (byte) 0xDF, (byte) 0xA3, 0, 0, 0, 0}),
          "clip.webm");
      assertRefused(writeBytes("clip.avi", ascii("RIFF\0\0\0\0AVI LIST")), "clip.avi");
      assertRefused(writeBytes("clip.flv", ascii("FLV\u0001\u0005\0\0\0\u0009")), "clip.flv");
    }

    @Test
    void theContainerDecides_notTheName() throws IOException {
      assertRefused(
          writeBytes("notes.pdf", ascii("\0\0\0\u0020ftypisom\0\0\u0002\0isomiso2mp41")),
          "notes.pdf");
    }

    @Test
    void aStillImageInTheSameContainerIsNoVideo() {
      assertTrue(
          !FileTypeDetector.isVideoContainer(ascii("RIFF\0\0\0\0WEBPVP8 ")), "a WebP is RIFF too");
      assertTrue(!FileTypeDetector.isVideoContainer(ascii("%PDF-1.7\n%\u00e2\u00e3")));
    }

    private static byte[] ascii(String s) {
      return s.getBytes(StandardCharsets.ISO_8859_1);
    }
  }

  @Nested
  class DetectAndValidate {

    @Test
    void emptyGpxAcceptedByLabelOrExtension() {
      assertDoesNotThrow(() ->
          detector.detectAndValidate(emptyGpxFile(), "empty.gpx", AssetType.ROUTE_ORIGINAL_GPX));
    }

    @Test
    void detectionFailureWrappedAsFileDetectionFailed() {
      File missing = tempDir.resolve("does-not-exist.png").toFile();
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () -> detector.detectAndValidate(missing, "missing.png", AssetType.IMAGE));
      assertEquals(ErrorCode.FILE_DETECTION_FAILED, ex.getErrorCode());
    }
  }
}

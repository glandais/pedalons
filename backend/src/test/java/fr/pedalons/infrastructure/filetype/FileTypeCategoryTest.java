package fr.pedalons.infrastructure.filetype;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.AssetType;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class FileTypeCategoryTest {

  @Nested
  class Image {

    @Test
    void acceptsCommonImageLabels() {
      for (String label : new String[] {"png", "jpeg", "gif", "webp", "bmp", "ico"}) {
        assertTrue(FileTypeCategory.IMAGE.accepts(label), label);
      }
    }

    @Test
    void rejectsSvg() {
      // docs/LEDGER_*.md SEC-1: a document that can carry script, not a picture
      assertFalse(FileTypeCategory.IMAGE.accepts("svg"));
    }

    @Test
    void rejectsJpeg2000() {
      // docs/LEDGER_*.md API-43. TIFF, HEIC, AVIF, JPEG XL are accepted before Magika is asked.
      assertFalse(FileTypeCategory.IMAGE.accepts("jp2"));
    }

    @Test
    void rejectsExecutableAndScriptLabels() {
      for (String label :
          new String[] {
            "pebin", "elf", "macho", "javascript", "html", "shell", "batch", "powershell"
          }) {
        assertFalse(FileTypeCategory.IMAGE.accepts(label), label);
      }
    }

    @Test
    void rejectsPdf() {
      assertFalse(FileTypeCategory.IMAGE.accepts("pdf"));
    }
  }

  @Nested
  class Gpx {

    @Test
    void acceptsXmlAndGpx() {
      assertTrue(FileTypeCategory.GPX.accepts("xml"));
      assertTrue(FileTypeCategory.GPX.accepts("gpx"));
    }

    @Test
    void rejectsPlainTextLabel() {
      assertFalse(
          FileTypeCategory.GPX.accepts("txt"),
          "txt is not in the GPX allowlist; small/empty GPX files rely on the .gpx extension"
              + " fallback in FileTypeDetector");
    }

    @Test
    void rejectsBinaryAndExecutableLabels() {
      assertFalse(FileTypeCategory.GPX.accepts("png"));
      assertFalse(FileTypeCategory.GPX.accepts("pdf"));
      assertFalse(FileTypeCategory.GPX.accepts("elf"));
      assertFalse(FileTypeCategory.GPX.accepts("html"));
    }
  }

  @Nested
  class Fit {

    @Test
    void anAllowlistDecidesOnTheLabelAlone() {
      assertTrue(FileTypeCategory.FIT.accepts("unknown", "randombytes"));
      assertFalse(FileTypeCategory.FIT.accepts("txt", "fit"));
    }

    @Test
    void acceptsFitAndUnknown() {
      assertTrue(FileTypeCategory.FIT.accepts("fit"));
      assertTrue(FileTypeCategory.FIT.accepts("unknown"));
    }

    @Test
    void rejectsTextAndScriptLabels() {
      assertFalse(FileTypeCategory.FIT.accepts("txt"));
      assertFalse(FileTypeCategory.FIT.accepts("xml"));
      assertFalse(FileTypeCategory.FIT.accepts("javascript"));
    }
  }

  @Nested
  class Attachment {

    @Test
    void acceptsDocumentLabels() {
      for (String label :
          new String[] {
            "pdf",
            "doc",
            "docx",
            "xls",
            "xlsx",
            "ppt",
            "pptx",
            "odt",
            "ods",
            "odp",
            "rtf",
            "epub",
            "markdown"
          }) {
        assertTrue(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void acceptsImageLabels() {
      for (String label : new String[] {"png", "jpeg", "gif", "webp", "bmp", "ico"}) {
        assertTrue(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void rejectsJpeg2000() {
      // docs/LEDGER_*.md API-43: its metadata cannot be removed
      assertFalse(FileTypeCategory.ATTACHMENT.accepts("jp2"));
    }

    @Test
    void acceptsArchiveLabels() {
      for (String label : new String[] {"zip", "sevenzip", "gzip", "bzip", "xz", "tar", "rar"}) {
        assertTrue(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void acceptsPlainTextLabels() {
      for (String label : new String[] {"txt", "csv", "tsv", "json", "yaml", "ics"}) {
        assertTrue(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void rejectsExecutableLabels() {
      for (String label :
          new String[] {
            "pebin",
            "elf",
            "macho",
            "apk",
            "dex",
            "wasm",
            "javabytecode",
            "pythonbytecode",
            "pickle",
            "msi",
            "dmg",
            "iso"
          }) {
        assertFalse(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void rejectsScriptAndMarkupLabels() {
      for (String label :
          new String[] {
            "javascript",
            "shell",
            "batch",
            "powershell",
            "vba",
            "php",
            "perl",
            "ruby",
            "python",
            "html",
            // docs/LEDGER_*.md SEC-1: both render as documents that can run script
            "svg",
            "xml"
          }) {
        assertFalse(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void rejectsVideoLabels() {
      // docs/LEDGER_*.md API-46: a recording carries where it was made
      for (String label : new String[] {"mp4", "qt", "3gp", "mkv", "webm", "flv"}) {
        assertFalse(FileTypeCategory.ATTACHMENT.accepts(label), label);
      }
    }

    @Test
    void rejectsUnknownAndEmpty() {
      assertFalse(FileTypeCategory.ATTACHMENT.accepts("unknown"));
      assertFalse(FileTypeCategory.ATTACHMENT.accepts("empty"));
    }

    @Test
    void refusesWhatTheModelReadBehindALowConfidenceLabel() {
      // docs/LEDGER_*.md SEC-53: Magika turns a script it is unsure of into txt
      assertFalse(FileTypeCategory.ATTACHMENT.accepts("txt", "powershell"));
      assertFalse(FileTypeCategory.ATTACHMENT.accepts("txt", "randomtxt"));
      assertTrue(FileTypeCategory.ATTACHMENT.accepts("txt", "txt"));
    }
  }

  @Nested
  class ForAssetType {

    @Test
    void mapsImageVariantsToImage() {
      for (AssetType type :
          new AssetType[] {
            AssetType.LOGO,
            AssetType.IMAGE,
            AssetType.ROUTE_THUMBNAIL_LIGHT,
            AssetType.ROUTE_THUMBNAIL_DARK,
            AssetType.RIDE_THUMBNAIL_LIGHT,
            AssetType.RIDE_THUMBNAIL_DARK,
            AssetType.TRIP_THUMBNAIL_LIGHT,
            AssetType.TRIP_THUMBNAIL_DARK
          }) {
        assertEquals(FileTypeCategory.IMAGE, FileTypeCategory.forAssetType(type), type.name());
      }
    }

    @Test
    void mapsGpxVariants() {
      assertEquals(
          FileTypeCategory.GPX, FileTypeCategory.forAssetType(AssetType.ROUTE_ORIGINAL_GPX));
      assertEquals(
          FileTypeCategory.GPX, FileTypeCategory.forAssetType(AssetType.ROUTE_FILTERED_GPX));
    }

    @Test
    void mapsFit() {
      assertEquals(FileTypeCategory.FIT, FileTypeCategory.forAssetType(AssetType.ROUTE_FIT));
    }

    @Test
    void mapsAttachment() {
      assertEquals(
          FileTypeCategory.ATTACHMENT, FileTypeCategory.forAssetType(AssetType.ATTACHMENT));
    }
  }
}

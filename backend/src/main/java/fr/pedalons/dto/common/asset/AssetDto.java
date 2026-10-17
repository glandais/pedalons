package fr.pedalons.dto.common.asset;

import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Builder
public record AssetDto(
    @Schema(description = "ID (TSID)", required = true) String id,
    @Schema(description = "Filename", required = true) String fileName,
    @Schema(description = "Content-Type", required = true) String contentType,
    @Schema(
            description =
                "Download URL. Opaque: it may carry a query string (a cache-buster that changes"
                    + " when the file is replaced); use it as is.",
            required = true)
        String url,
    @Schema(
            description =
                "Image URL template. Opaque: it may carry a query string (a cache-buster that"
                    + " changes when the file is replaced); substitute {size} only.")
        @Nullable String imageUrl,
    @Schema(description = "image dimensions") @Nullable AssetDimensionsDto imageDimensions,
    @Schema(
            description =
                "Size in bytes of the file a download returns (an image as re-encoded on upload);"
                    + " null while not yet known. Ignored in requests.")
        @Nullable Long size) {}

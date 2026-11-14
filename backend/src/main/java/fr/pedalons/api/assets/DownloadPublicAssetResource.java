package fr.pedalons.api.assets;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.service.user.UserAvatarService;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/** Files and images whose URL was built for content visible to anyone. */
@Path("/api/download/public")
@Tag(
    name = "Downloads",
    description =
        "Files (GPX, FIT, documents), images and avatars, under the URLs the API hands out")
public class DownloadPublicAssetResource extends AbstractDownloadAssetResource {

  @Inject UserAvatarService userAvatarService;

  @GET
  @Path("assets/{teamSlug}/{assetId}/{fileName}")
  @PermitAll
  @Operation(
      operationId = "downloadPublicAsset",
      summary = "Download a file",
      description = ASSET_DESCRIPTION)
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The file, with its own content type",
        content =
            @Content(
                mediaType = "application/octet-stream",
                schema = @Schema(type = SchemaType.STRING, format = "binary"))),
    @APIResponse(
        responseCode = "403",
        description = "The caller may not read this asset",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "No such asset",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response downloadAsset(
      @Parameter(description = "Team slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Asset ID") @PathParam("assetId") String assetId,
      @Parameter(description = "File name: the last segment of the URL, not used to find the file")
          @PathParam("fileName")
          String fileName) {
    return asset(teamSlug, assetId);
  }

  @GET
  @Path("images/{teamSlug}/{assetId}/{size}")
  @PermitAll
  @Operation(
      operationId = "downloadPublicImage",
      summary = "Download an image",
      description = IMAGE_DESCRIPTION)
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The image",
        content =
            @Content(
                mediaType = "image/*",
                schema = @Schema(type = SchemaType.STRING, format = "binary"))),
    @APIResponse(
        responseCode = "403",
        description = "The caller may not read this asset",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "No such asset",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response downloadImage(
      @HeaderParam("Accept") String accept,
      @Parameter(description = "Team slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Asset ID") @PathParam("assetId") String assetId,
      @Parameter(description = "Requested square size in pixels") @PathParam("size") int size) {
    return image(accept, teamSlug, assetId, size);
  }

  @GET
  @Path("/avatars/{fileId}/{size}")
  @PermitAll
  @Operation(
      operationId = "downloadAvatar",
      summary = "Download a user's avatar",
      description =
          "Serves an avatar under the URL the API gave for it (avatarUrl), in the best format"
              + " the Accept header allows. Avatars are stored at 256 px: a larger size is served"
              + " at 256.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The image",
        content =
            @Content(
                mediaType = "image/*",
                schema = @Schema(type = SchemaType.STRING, format = "binary"))),
    @APIResponse(
        responseCode = "404",
        description = "No such avatar",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getAvatar(
      @HeaderParam("Accept") String accept,
      @Parameter(description = "Avatar file ID, from avatarUrl") @PathParam("fileId") String fileId,
      @Parameter(description = "Requested square size in pixels") @PathParam("size") int size) {
    return userAvatarService.getAvatar(fileId, size, accept);
  }
}

package fr.pedalons.api.admin;

import fr.pedalons.dto.admin.AdminActivationResponse;
import fr.pedalons.dto.admin.AdminDomainAliasDto;
import fr.pedalons.dto.admin.AdminDomainDto;
import fr.pedalons.dto.admin.AdminDomainListResponse;
import fr.pedalons.dto.admin.AdminGpsCredentialDto;
import fr.pedalons.dto.admin.AdminStatsDto;
import fr.pedalons.dto.admin.CreateDomainAliasRequest;
import fr.pedalons.dto.admin.CreateDomainRequest;
import fr.pedalons.dto.admin.CreateGpsCredentialRequest;
import fr.pedalons.dto.admin.UpdateDomainAliasRequest;
import fr.pedalons.dto.admin.UpdateDomainRequest;
import fr.pedalons.dto.admin.UpdateGpsCredentialRequest;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.service.admin.AdminDomainAliasService;
import fr.pedalons.service.admin.AdminDomainGpsCredentialService;
import fr.pedalons.service.admin.AdminDomainService;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/api/admin/domains")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Admin - Domains", description = "Platform admin domain management")
public class AdminDomainResource {

  @Inject AdminDomainService adminDomainService;

  @Inject AdminDomainGpsCredentialService gpsCredentialService;

  @Inject AdminDomainAliasService aliasService;

  @GET
  @Path("/stats")
  @Admin
  @Operation(
      operationId = "getStats",
      summary = "Get platform statistics",
      description = "Get overall platform statistics")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Statistics retrieved successfully",
        content = @Content(schema = @Schema(implementation = AdminStatsDto.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getStats() {
    AdminStatsDto stats = adminDomainService.getStats();
    return Response.ok(stats).build();
  }

  @GET
  @Path("/activation")
  @Admin
  @Operation(
      operationId = "getActivation",
      summary = "Activation of new accounts",
      description =
          "Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a"
              + " team and that signed up to a ride within 7 days. Counts only, computed on the"
              + " data already stored — no person is named (ledger API-213).")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Activation counts",
        content = @Content(schema = @Schema(implementation = AdminActivationResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getActivation(
      @Parameter(description = "Sign-up weeks back, the current one included (1 to 52)")
          @QueryParam("weeks")
          @DefaultValue("12")
          int weeks) {
    return Response.ok(adminDomainService.getActivation(weeks)).build();
  }

  @GET
  @Admin
  @Operation(
      operationId = "listDomains",
      summary = "List all domains",
      description = "Get a paginated list of all domains")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Domains retrieved successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainListResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listDomains(
      @Parameter(description = "Page number (0-indexed)") @QueryParam("page") @DefaultValue("0")
          int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("20") int size) {

    PedalonsPage<AdminDomainDto> result = adminDomainService.listDomains(page, size);
    AdminDomainListResponse response =
        new AdminDomainListResponse(result.items(), result.total(), page, size);
    return Response.ok(response).build();
  }

  @GET
  @Path("/{domainId}")
  @Admin
  @Operation(
      operationId = "getDomain",
      summary = "Get domain details",
      description = "Get detailed domain information")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Domain retrieved successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getDomain(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId) {

    AdminDomainDto domain = adminDomainService.getDomain(domainId);
    return Response.ok(domain).build();
  }

  @POST
  @Admin
  @Operation(
      operationId = "createDomain",
      summary = "Create domain",
      description = "Create a new domain")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Domain created successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response createDomain(@Valid CreateDomainRequest request) {

    AdminDomainDto domain =
        adminDomainService.createDomain(
            request.domain(),
            request.name(),
            request.baseUrl(),
            request.singleTeam(),
            request.enableGpxPlanner(),
            request.androidFingerprints());
    return Response.status(Response.Status.CREATED).entity(domain).build();
  }

  @PUT
  @Path("/{domainId}")
  @Admin
  @Operation(
      operationId = "updateDomain",
      summary = "Update domain",
      description = "Update domain information")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Domain updated successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response updateDomain(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Valid UpdateDomainRequest request) {

    AdminDomainDto domain =
        adminDomainService.updateDomain(
            domainId,
            request.name(),
            request.baseUrl(),
            request.singleTeam(),
            request.enableGpxPlanner(),
            request.androidFingerprints());
    return Response.ok(domain).build();
  }

  @POST
  @Path("/{domainId}/toggle-active")
  @Admin
  @Operation(
      operationId = "toggleDomainActive",
      summary = "Toggle domain active status",
      description = "Enable or disable a domain")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Domain status toggled successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response toggleDomainActive(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId) {

    AdminDomainDto domain = adminDomainService.toggleDomainActive(domainId);
    return Response.ok(domain).build();
  }

  // GPS Credentials endpoints

  @GET
  @Path("/{domainId}/gps-credentials")
  @Admin
  @Operation(
      operationId = "listDomainGpsCredentials",
      summary = "List GPS credentials",
      description = "Get all GPS credentials for a domain")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Credentials retrieved successfully",
        content =
            @Content(
                schema =
                    @Schema(
                        type = org.eclipse.microprofile.openapi.annotations.enums.SchemaType.ARRAY,
                        implementation = AdminGpsCredentialDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listDomainGpsCredentials(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId) {

    List<AdminGpsCredentialDto> credentials = gpsCredentialService.listCredentials(domainId);
    return Response.ok(credentials).build();
  }

  @POST
  @Path("/{domainId}/gps-credentials")
  @Admin
  @Operation(
      operationId = "createDomainGpsCredential",
      summary = "Create GPS credential",
      description = "Create a new GPS credential for a domain")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Credential created successfully",
        content = @Content(schema = @Schema(implementation = AdminGpsCredentialDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Credential already exists for this service type",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response createDomainGpsCredential(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Valid CreateGpsCredentialRequest request) {

    AdminGpsCredentialDto credential = gpsCredentialService.createCredential(domainId, request);
    return Response.status(Response.Status.CREATED).entity(credential).build();
  }

  @PUT
  @Path("/{domainId}/gps-credentials/{credentialId}")
  @Admin
  @Operation(
      operationId = "updateDomainGpsCredential",
      summary = "Update GPS credential",
      description = "Update a GPS credential for a domain")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Credential updated successfully",
        content = @Content(schema = @Schema(implementation = AdminGpsCredentialDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain or credential not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response updateDomainGpsCredential(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Parameter(description = "Credential ID") @PathParam("credentialId") String credentialId,
      @Valid UpdateGpsCredentialRequest request) {

    AdminGpsCredentialDto credential =
        gpsCredentialService.updateCredential(domainId, credentialId, request);
    return Response.ok(credential).build();
  }

  @DELETE
  @Path("/{domainId}/gps-credentials/{credentialId}")
  @Admin
  @Operation(
      operationId = "deleteDomainGpsCredential",
      summary = "Delete GPS credential",
      description = "Delete a GPS credential for a domain")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Credential deleted successfully"),
    @APIResponse(
        responseCode = "404",
        description = "Domain or credential not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response deleteDomainGpsCredential(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Parameter(description = "Credential ID") @PathParam("credentialId") String credentialId) {

    gpsCredentialService.deleteCredential(domainId, credentialId);
    return Response.noContent().build();
  }

  // Domain alias endpoints (dedicated hostnames pinned to a team)

  @GET
  @Path("/{domainId}/aliases")
  @Admin
  @Operation(
      operationId = "listDomainAliases",
      summary = "List domain aliases",
      description = "Get all dedicated hostnames (aliases) pinned to teams of a domain")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Aliases retrieved successfully",
        content =
            @Content(
                schema =
                    @Schema(
                        type = org.eclipse.microprofile.openapi.annotations.enums.SchemaType.ARRAY,
                        implementation = AdminDomainAliasDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listDomainAliases(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId) {

    List<AdminDomainAliasDto> aliases = aliasService.listAliases(domainId);
    return Response.ok(aliases).build();
  }

  @POST
  @Path("/{domainId}/aliases")
  @Admin
  @Operation(
      operationId = "createDomainAlias",
      summary = "Create domain alias",
      description = "Create a dedicated hostname pinned to a team of the domain")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Alias created successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainAliasDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain or team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Hostname already in use",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response createDomainAlias(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Valid CreateDomainAliasRequest request) {

    AdminDomainAliasDto alias = aliasService.createAlias(domainId, request);
    return Response.status(Response.Status.CREATED).entity(alias).build();
  }

  @PUT
  @Path("/{domainId}/aliases/{aliasId}")
  @Admin
  @Operation(
      operationId = "updateDomainAlias",
      summary = "Update domain alias",
      description = "Update a dedicated hostname's pinned team or branding")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Alias updated successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainAliasDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain, alias or team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response updateDomainAlias(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Parameter(description = "Alias ID") @PathParam("aliasId") String aliasId,
      @Valid UpdateDomainAliasRequest request) {

    AdminDomainAliasDto alias = aliasService.updateAlias(domainId, aliasId, request);
    return Response.ok(alias).build();
  }

  @POST
  @Path("/{domainId}/aliases/{aliasId}/toggle-active")
  @Admin
  @Operation(
      operationId = "toggleDomainAliasActive",
      summary = "Toggle domain alias active status",
      description = "Enable or disable a dedicated hostname")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Alias status toggled successfully",
        content = @Content(schema = @Schema(implementation = AdminDomainAliasDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Domain or alias not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response toggleDomainAliasActive(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Parameter(description = "Alias ID") @PathParam("aliasId") String aliasId) {

    AdminDomainAliasDto alias = aliasService.toggleAliasActive(domainId, aliasId);
    return Response.ok(alias).build();
  }

  @DELETE
  @Path("/{domainId}/aliases/{aliasId}")
  @Admin
  @Operation(
      operationId = "deleteDomainAlias",
      summary = "Delete domain alias",
      description = "Delete a dedicated hostname")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Alias deleted successfully"),
    @APIResponse(
        responseCode = "404",
        description = "Domain or alias not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response deleteDomainAlias(
      @Parameter(description = "Domain ID") @PathParam("domainId") String domainId,
      @Parameter(description = "Alias ID") @PathParam("aliasId") String aliasId) {

    aliasService.deleteAlias(domainId, aliasId);
    return Response.noContent().build();
  }
}

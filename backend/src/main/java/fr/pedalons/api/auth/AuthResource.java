package fr.pedalons.api.auth;

import fr.pedalons.dto.auth.request.ActivateAccountRequest;
import fr.pedalons.dto.auth.request.EmailChangeRequest;
import fr.pedalons.dto.auth.request.ForgotPasswordRequest;
import fr.pedalons.dto.auth.request.LoginRequest;
import fr.pedalons.dto.auth.request.OtpRequest;
import fr.pedalons.dto.auth.request.RegisterRequest;
import fr.pedalons.dto.auth.request.ResetPasswordRequest;
import fr.pedalons.dto.auth.request.VerifyOtpRequest;
import fr.pedalons.dto.auth.request.VerifyTokenRequest;
import fr.pedalons.dto.auth.response.AuthResponse;
import fr.pedalons.dto.auth.response.AuthResult;
import fr.pedalons.dto.auth.response.EmailLinkPreviewResponse;
import fr.pedalons.dto.auth.response.MessageResponse;
import fr.pedalons.dto.auth.response.RefreshResult;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.service.auth.AuthService;
import fr.pedalons.service.auth.RefreshTokenCookieFactory;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

@Path("/api/auth")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Authentication", description = "User authentication operations")
public class AuthResource {

  private static final String REFRESH_TOKEN_COOKIE = RefreshTokenCookieFactory.REFRESH_TOKEN_COOKIE;

  @Inject AuthService authService;
  @Inject RefreshTokenCookieFactory refreshTokenCookies;

  @POST
  @Path("/register")
  @PermitAll
  @Operation(
      summary = "Register new user",
      description = "Register a new user. A verification email will be sent.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Registration initiated, verification email sent",
        content = @Content(schema = @Schema(implementation = MessageResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request or email already registered",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "500",
        description =
            "EMAIL_NOT_SENT — the verification email could not be sent. Nothing was created;"
                + " trying again sends a new link.",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response register(@Valid RegisterRequest request) {
    authService.register(request);
    return Response.ok(new MessageResponse("Verification email sent")).build();
  }

  @POST
  @Path("/verify-email/preview")
  @PermitAll
  @Operation(
      summary = "Read a verification link",
      description =
          "The address a sign-up or address-change link verifies, and what following it does."
              + " Does not spend the link: the page shows the address before anything happens.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The link is valid",
        content = @Content(schema = @Schema(implementation = EmailLinkPreviewResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid, spent or expired link",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public EmailLinkPreviewResponse previewEmailLink(@Valid VerifyTokenRequest request) {
    return authService.previewEmailLink(request.token());
  }

  @POST
  @Path("/verify-email")
  @PermitAll
  @Operation(
      summary = "Activate an account",
      description =
          "Complete a sign-up from its verification link: the password is chosen here, then the"
              + " new account is signed in.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Account created and signed in",
        content = @Content(schema = @Schema(implementation = AuthResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid, spent or expired link, or not a sign-up link",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response activateAccount(
      @Valid ActivateAccountRequest request,
      @Context HttpHeaders headers,
      @HeaderParam("X-Forwarded-For") @Nullable String forwardedFor,
      @HeaderParam("X-Real-IP") @Nullable String realIp) {
    String userAgent = headers.getHeaderString(HttpHeaders.USER_AGENT);
    String ipAddress = getClientIp(forwardedFor, realIp);

    AuthResult result =
        authService.activateAccount(request.token(), request.password(), userAgent, ipAddress);
    return Response.ok(result.response())
        .cookie(refreshTokenCookies.issue(result.refreshToken()))
        .build();
  }

  @POST
  @Path("/confirm-email-change")
  @PermitAll
  @Operation(
      summary = "Confirm a new address",
      description =
          "Apply an address change from its link. Opens no session: a signed-in client refreshes"
              + " its user.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Address changed"),
    @APIResponse(
        responseCode = "400",
        description = "Invalid, spent or expired link, or not an address-change link",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "EMAIL_ALREADY_EXISTS — another account took the address meanwhile",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public void confirmEmailChange(@Valid VerifyTokenRequest request) {
    authService.confirmEmailChange(request.token());
  }

  @POST
  @Path("/otp")
  @PermitAll
  @Operation(
      summary = "Request OTP",
      description = "Send a 6-digit OTP code to the user's email for passwordless login")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "OTP sent (if email exists)",
        content = @Content(schema = @Schema(implementation = MessageResponse.class)))
  })
  public Response requestOtp(@Valid OtpRequest request) {
    authService.requestOtp(request);
    return Response.ok(new MessageResponse("If the email exists, a code has been sent")).build();
  }

  @POST
  @Path("/otp/verify")
  @PermitAll
  @Operation(summary = "Verify OTP", description = "Verify OTP code and authenticate")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Login successful",
        content = @Content(schema = @Schema(implementation = AuthResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid or expired code",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response verifyOtp(
      @Valid VerifyOtpRequest request,
      @Context HttpHeaders headers,
      @HeaderParam("X-Forwarded-For") @Nullable String forwardedFor,
      @HeaderParam("X-Real-IP") @Nullable String realIp) {
    String userAgent = headers.getHeaderString(HttpHeaders.USER_AGENT);
    String ipAddress = getClientIp(forwardedFor, realIp);

    AuthResult result =
        authService.verifyOtp(request.email(), request.code(), userAgent, ipAddress);
    return Response.ok(result.response())
        .cookie(refreshTokenCookies.issue(result.refreshToken()))
        .build();
  }

  @POST
  @Path("/login")
  @PermitAll
  @Operation(summary = "Login with password", description = "Authenticate using email and password")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Login successful",
        content = @Content(schema = @Schema(implementation = AuthResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid credentials or password not set",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "429",
        description =
            "LOGIN_RATE_LIMITED — too many wrong passwords lately for this address; Retry-After"
                + " gives the wait",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response loginWithPassword(
      @Valid LoginRequest request,
      @Context HttpHeaders headers,
      @HeaderParam("X-Forwarded-For") @Nullable String forwardedFor,
      @HeaderParam("X-Real-IP") @Nullable String realIp) {
    String userAgent = headers.getHeaderString(HttpHeaders.USER_AGENT);
    String ipAddress = getClientIp(forwardedFor, realIp);

    AuthResult result =
        authService.loginWithPassword(request.email(), request.password(), userAgent, ipAddress);
    return Response.ok(result.response())
        .cookie(refreshTokenCookies.issue(result.refreshToken()))
        .build();
  }

  @POST
  @Path("/forgot-password")
  @PermitAll
  @Operation(
      summary = "Request password reset",
      description = "Send a 6-digit code to the user's email to reset their password")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Reset code sent (if email exists)",
        content = @Content(schema = @Schema(implementation = MessageResponse.class)))
  })
  public Response forgotPassword(@Valid ForgotPasswordRequest request) {
    authService.requestPasswordReset(request.email());
    return Response.ok(new MessageResponse("If the email exists, a reset code has been sent"))
        .build();
  }

  @POST
  @Path("/reset-password")
  @PermitAll
  @Operation(
      summary = "Reset password",
      description = "Verify the reset token and set a new password")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Password reset, logged in",
        content = @Content(schema = @Schema(implementation = AuthResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid or expired token",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response resetPassword(
      @Valid ResetPasswordRequest request,
      @Context HttpHeaders headers,
      @HeaderParam("X-Forwarded-For") @Nullable String forwardedFor,
      @HeaderParam("X-Real-IP") @Nullable String realIp) {
    String userAgent = headers.getHeaderString(HttpHeaders.USER_AGENT);
    String ipAddress = getClientIp(forwardedFor, realIp);

    AuthResult result =
        authService.resetPassword(request.token(), request.newPassword(), userAgent, ipAddress);
    return Response.ok(result.response())
        .cookie(refreshTokenCookies.issue(result.refreshToken()))
        .build();
  }

  @POST
  @Path("/refresh")
  @PermitAll
  @Operation(
      summary = "Refresh access token",
      description =
          "Get a new access token from the refresh token (cookie on the web, X-Refresh-Token"
              + " header on mobile). The refresh token is rotated: the new one comes back in the"
              + " cookie, or in refreshToken for the header flow, and the one presented is then"
              + " only honoured for a short grace, without rotating again (refreshToken absent)."
              + " Presented after that grace, it is rotated again from itself: the successor it"
              + " had (lost by the client) is dropped, and it is refused once the new one is"
              + " presented.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Token refreshed successfully",
        content = @Content(schema = @Schema(implementation = AuthResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Invalid or expired refresh token",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response refresh(
      @CookieParam(REFRESH_TOKEN_COOKIE) @Nullable String refreshTokenCookie,
      @HeaderParam("X-Refresh-Token") @Nullable String refreshTokenHeader,
      @Context HttpHeaders headers,
      @HeaderParam("X-Forwarded-For") @Nullable String forwardedFor,
      @HeaderParam("X-Real-IP") @Nullable String realIp) {
    // Cookie (web) or header (mobile) — cookie takes priority
    boolean fromCookie = refreshTokenCookie != null && !refreshTokenCookie.isBlank();
    String refreshToken = fromCookie ? refreshTokenCookie : refreshTokenHeader;
    if (refreshToken == null || refreshToken.isBlank()) {
      return Response.status(Response.Status.FORBIDDEN).build();
    }

    RefreshResult result = authService.refreshToken(refreshToken);
    String nextToken = result.refreshToken();
    if (!fromCookie) {
      // Mobile: the new token travels in the body, the only place the app reads it from.
      return Response.ok(
              nextToken == null
                  ? result.response()
                  : result.response().toBuilder().refreshToken(nextToken).build())
          .build();
    }
    // Web: the new token stays in the HttpOnly cookie, never in a body script can read. Inside the
    // grace of another refresh's rotation there is none, and the cookie that refresh set stands.
    // issue() also drops any leftover path=/api cookie.
    Response.ResponseBuilder response = Response.ok(result.response());
    if (nextToken != null) {
      response.cookie(refreshTokenCookies.issue(nextToken));
    }
    return response.build();
  }

  @POST
  @Path("/email/change-request")
  @RolesAllowed("user")
  @Operation(
      summary = "Request email change",
      description =
          "Change the signed-in user's email address. Sends a verification link to the new"
              + " address; the change applies once that link is followed.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Verification email sent to the new address",
        content = @Content(schema = @Schema(implementation = MessageResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Email already used by another account",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response requestEmailChange(@Valid EmailChangeRequest request) {
    authService.requestEmailChange(request.email());
    return Response.ok(new MessageResponse("Verification email sent")).build();
  }

  @POST
  @Path("/logout")
  @PermitAll
  @Operation(summary = "Logout", description = "Logout and invalidate the refresh token")
  @APIResponses({@APIResponse(responseCode = "204", description = "Logged out successfully")})
  public Response logout(
      @CookieParam(REFRESH_TOKEN_COOKIE) @Nullable String refreshTokenCookie,
      @HeaderParam("X-Refresh-Token") @Nullable String refreshTokenHeader) {
    String refreshToken =
        (refreshTokenCookie != null && !refreshTokenCookie.isBlank())
            ? refreshTokenCookie
            : refreshTokenHeader;
    authService.logout(refreshToken);
    return Response.noContent().cookie(refreshTokenCookies.revoke()).build();
  }

  @POST
  @Path("/logout-all")
  @RolesAllowed("user")
  @Operation(
      summary = "Logout all sessions",
      description = "Logout from all devices by invalidating all refresh tokens")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "All sessions invalidated"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response logoutAll() {
    authService.logoutAll();
    return Response.noContent().cookie(refreshTokenCookies.revoke()).build();
  }

  private String getClientIp(@Nullable String forwardedFor, @Nullable String realIp) {
    if (forwardedFor != null && !forwardedFor.isBlank()) {
      return forwardedFor.split(",")[0].trim();
    }
    if (realIp != null && !realIp.isBlank()) {
      return realIp;
    }
    return "unknown";
  }
}

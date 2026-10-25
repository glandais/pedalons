package fr.pedalons.service.migration.live;

import fr.pedalons.service.migration.SourceFileUnavailableException;
import fr.pedalons.service.migration.live.snapshot.BiketeamFileFetcher;
import fr.pedalons.service.migration.live.snapshot.BiketeamSnapshot;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.regex.Pattern;
import org.jspecify.annotations.Nullable;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Client of biketeam's M2M export API, over HTTPS (docs/plans/2026-09-22-biketeam-live-migration.md
 * §6): the team snapshot, and its files one by one. Authenticated by {@code
 * X-Pedalons-Export-Secret}; biketeam serves a team only while it has a migration of it in flight.
 *
 * <p>Plain {@code java.net.http}: two GETs, no need for a REST client declaration whose base URL
 * would have to exist even when the feature is off.
 */
@ApplicationScoped
public class BiketeamExportClient implements BiketeamFileFetcher {

  static final String SECRET_HEADER = "X-Pedalons-Export-Secret";
  static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);

  /**
   * Until the response headers of a file only: the body is bounded by {@link TimedBodySubscriber},
   * with {@code export-idle-timeout} and {@code export-transfer-timeout}. The snapshot's headers
   * wait {@code export-snapshot-timeout} instead: biketeam may have to hash every file of a big
   * team before it can answer.
   */
  static final Duration FILE_REQUEST_TIMEOUT = Duration.ofSeconds(120);

  private static final Runnable NO_HEARTBEAT = () -> {};

  /** Biketeam's code for a file that is not there, or not of the team (§6 of the plan). */
  static final String FILE_NOT_FOUND = "FILE_NOT_FOUND";

  /** What an error code of biketeam looks like — an HTML page or a proxy's JSON does not. */
  private static final Pattern CODE = Pattern.compile("^[A-Z][A-Z0-9_]{1,63}$");

  @Inject BiketeamLiveMigrationConfig config;
  @Inject ObjectMapper objectMapper;

  private final HttpClient http =
      HttpClient.newBuilder()
          .connectTimeout(CONNECT_TIMEOUT)
          .followRedirects(HttpClient.Redirect.NEVER)
          .build();

  /**
   * {@code GET /internal/pedalons/teams/{teamId}/snapshot}.
   *
   * <p>Only biketeam itself can refuse: a 4xx is REFUSED when its body is biketeam's JSON error,
   * {@code {"code": ...}}. A 4xx without it — a proxy with no route, biketeam restarting, the export
   * switched off (a bare 404) — says nothing about the team, and is retried like a 5xx.
   *
   * @throws BiketeamExportException REFUSED on a 4xx carrying biketeam's error code, UNAVAILABLE on
   *     any other non-200 answer or a network failure, INVALID when the body cannot be read
   */
  public BiketeamSnapshot fetchSnapshot(String teamId) {
    return fetchSnapshot(teamId, NO_HEARTBEAT);
  }

  /**
   * Same, calling {@code heartbeat} on this thread as the body comes in.
   *
   * @see TimedBodySubscriber
   */
  public BiketeamSnapshot fetchSnapshot(String teamId, Runnable heartbeat) {
    URI uri =
        URI.create(
            config.exportUrl()
                + "/internal/pedalons/teams/"
                + URLEncoder.encode(teamId, StandardCharsets.UTF_8).replace("+", "%20")
                + "/snapshot");
    HttpResponse<InputStream> response;
    try {
      response =
          http.send(
              request(uri, config.exportSnapshotTimeout()), bodyHandler("the snapshot", heartbeat));
    } catch (IOException e) {
      throw new BiketeamExportException(
          BiketeamExportException.Kind.UNAVAILABLE, "Export unreachable: " + describe(e), e);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new BiketeamExportException(
          BiketeamExportException.Kind.UNAVAILABLE, "Interrupted while fetching the snapshot", e);
    }
    int status = response.statusCode();
    try (InputStream body = response.body()) {
      if (status != 200) {
        String code = status >= 400 && status < 500 ? errorCode(body.readNBytes(4096)) : null;
        throw new BiketeamExportException(
            code != null
                ? BiketeamExportException.Kind.REFUSED
                : BiketeamExportException.Kind.UNAVAILABLE,
            "Export answered " + status + (code != null ? " (" + code + ")" : ""));
      }
      try {
        return objectMapper.readValue(body, BiketeamSnapshot.class);
      } catch (JacksonException e) {
        // Jackson wraps what the heartbeat throws mid-body: the job is no longer ours.
        for (Throwable t = e.getCause(); t != null && t != t.getCause(); t = t.getCause()) {
          if (t instanceof BiketeamJobLostException lost) {
            throw lost;
          }
        }
        if (body instanceof TimedBodySubscriber timed && timed.failed()) {
          // The transfer stalled or dropped: the export, not the snapshot — retried.
          throw new BiketeamExportException(
              BiketeamExportException.Kind.UNAVAILABLE, "Export read failed: " + describe(e), e);
        }
        throw new BiketeamExportException(
            BiketeamExportException.Kind.INVALID, "Unreadable snapshot: " + describe(e), e);
      }
    } catch (IOException e) {
      throw new BiketeamExportException(
          BiketeamExportException.Kind.UNAVAILABLE, "Export read failed: " + describe(e), e);
    }
  }

  /**
   * {@code GET {export-url}{path}} into {@code target}.
   *
   * <p>Only a {@code 404 {"code":"FILE_NOT_FOUND"}} concerns this file alone: it is missing, and
   * the element carries on without it ({@link SourceFileUnavailableException}). Everything else is
   * about the export, not the file, and ends the job's attempt: another 4xx carrying biketeam's
   * error code (the migration no longer in flight, the secret refused) is REFUSED; a network
   * failure, a 3xx, a 5xx or a 4xx without biketeam's body (the export restarting or switched off)
   * is UNAVAILABLE, and the job is retried — never completed without the file.
   *
   * @throws SourceFileUnavailableException the file is missing on biketeam's side
   * @throws BiketeamExportException the export refused or could not be reached
   */
  @Override
  public void download(String path, Path target) throws IOException {
    download(path, target, NO_HEARTBEAT);
  }

  /** The fetcher of a job's files, calling {@code heartbeat} on this thread as bodies come in. */
  public BiketeamFileFetcher withHeartbeat(Runnable heartbeat) {
    return (path, target) -> download(path, target, heartbeat);
  }

  /** {@link #download(String, Path)}, calling {@code heartbeat} as the body comes in. */
  public void download(String path, Path target, Runnable heartbeat) throws IOException {
    URI uri = URI.create(config.exportUrl() + path);
    HttpResponse<InputStream> response;
    try {
      response = http.send(request(uri, FILE_REQUEST_TIMEOUT), bodyHandler(path, heartbeat));
    } catch (IOException e) {
      throw new BiketeamExportException(
          BiketeamExportException.Kind.UNAVAILABLE,
          "Download of " + path + " failed: " + describe(e),
          e);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new BiketeamExportException(
          BiketeamExportException.Kind.UNAVAILABLE, "Interrupted while downloading " + path, e);
    }
    int status = response.statusCode();
    try (InputStream body = response.body()) {
      if (status != 200) {
        String code = status >= 400 && status < 500 ? errorCode(body.readNBytes(4096)) : null;
        if (status == 404 && FILE_NOT_FOUND.equals(code)) {
          throw new SourceFileUnavailableException("No file at " + path + " (" + code + ")");
        }
        throw new BiketeamExportException(
            code != null
                ? BiketeamExportException.Kind.REFUSED
                : BiketeamExportException.Kind.UNAVAILABLE,
            "Download of "
                + path
                + " answered "
                + status
                + (code != null ? " (" + code + ")" : ""));
      }
      Files.copy(body, target, StandardCopyOption.REPLACE_EXISTING);
    } catch (SourceFileUnavailableException e) {
      throw e;
    } catch (IOException e) {
      // The connection dropped, stalled or took too long mid-body: the export, not the file.
      throw new BiketeamExportException(
          BiketeamExportException.Kind.UNAVAILABLE,
          "Download of " + path + " failed: " + describe(e),
          e);
    }
  }

  private HttpResponse.BodyHandler<InputStream> bodyHandler(String what, Runnable heartbeat) {
    return TimedBodySubscriber.handler(
        config.exportIdleTimeout(), config.exportTransferTimeout(), what, heartbeat);
  }

  private HttpRequest request(URI uri, Duration headersTimeout) {
    return HttpRequest.newBuilder(uri)
        .timeout(headersTimeout)
        .header(SECRET_HEADER, config.exportSecret())
        .header("Accept", "application/json, */*")
        .GET()
        .build();
  }

  /**
   * The {@code code} of biketeam's JSON error body — {@code {"code": "...", ...}} — or null when the
   * body is not one: then the answer came from something other than biketeam's export. Only the
   * code is kept, for the job's error message; never the body.
   */
  @Nullable String errorCode(byte[] body) {
    if (body.length == 0) {
      return null;
    }
    try {
      JsonNode node = objectMapper.readTree(body);
      if (node != null && node.isObject()) {
        JsonNode code = node.get("code");
        if (code != null && code.isString() && CODE.matcher(code.stringValue()).matches()) {
          return code.stringValue();
        }
      }
    } catch (RuntimeException e) {
      // Not JSON: not biketeam's answer.
    }
    return null;
  }

  /**
   * An exception as a job error message: network failures often carry no message at all, which
   * would read "Export unreachable: null".
   */
  static String describe(Throwable e) {
    String message = e.getMessage();
    return message == null || message.isBlank()
        ? e.getClass().getSimpleName()
        : e.getClass().getSimpleName() + ": " + message;
  }
}

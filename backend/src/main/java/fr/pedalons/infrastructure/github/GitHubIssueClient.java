package fr.pedalons.infrastructure.github;

import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Opens, reads, reopens and comments issues of the feedback repository.
 *
 * <p>Configuration is all-or-nothing, like {@code FcmClient}: without a token and an {@code
 * owner/repo}, {@link #isConfigured()} is false and the feedback rows simply stay {@code PENDING} —
 * the case of a workstation and of the tests. The token is a fine-grained PAT restricted to that one
 * private repository, with the Issues permission only.
 */
@ApplicationScoped
public class GitHubIssueClient {

  private static final Logger LOG = Logger.getLogger(GitHubIssueClient.class);

  @ConfigProperty(name = "pedalons.feedback.github.repo")
  Optional<String> repository;

  @ConfigProperty(name = "pedalons.feedback.github.token")
  Optional<String> token;

  @Inject ObjectMapper objectMapper;
  @Inject @RestClient GitHubRestClient github;

  private @Nullable String owner;
  private @Nullable String repo;

  /** Whether an issue is closed on GitHub, and since when. */
  public record IssueStatus(boolean closed, @Nullable Instant closedAt) {}

  @PostConstruct
  void init() {
    if (token.isEmpty() || token.get().isBlank() || repository.isEmpty()) {
      LOG.info("Feedback GitHub publication disabled: no token or repository configured");
      return;
    }
    String[] parts = repository.get().trim().split("/");
    if (parts.length != 2 || parts[0].isBlank() || parts[1].isBlank()) {
      LOG.errorf(
          "Feedback GitHub publication disabled: pedalons.feedback.github.repo must be"
              + " owner/repo, got '%s'",
          repository.get());
      return;
    }
    owner = parts[0];
    repo = parts[1];
    LOG.infof("Feedback GitHub publication enabled — %s/%s", owner, repo);
  }

  public boolean isConfigured() {
    return owner != null && repo != null;
  }

  /**
   * @return the number of the new issue
   */
  public int createIssue(String title, String body, List<String> labels) {
    JsonNode issue =
        call(
            "create issue",
            () ->
                github.createIssue(
                    owner(),
                    repo(),
                    auth(),
                    Map.of("title", title, "body", body, "labels", labels)));
    return issue.get("number").asInt();
  }

  public void comment(int number, String body) {
    call(
        "comment issue #" + number,
        () -> github.comment(owner(), repo(), number, auth(), Map.of("body", body)));
  }

  public IssueStatus status(int number) {
    JsonNode issue =
        call("read issue #" + number, () -> github.getIssue(owner(), repo(), number, auth()));
    boolean closed = "closed".equals(issue.path("state").asString());
    String closedAt = issue.path("closed_at").asString(null);
    return new IssueStatus(closed, closed && closedAt != null ? Instant.parse(closedAt) : null);
  }

  public void reopen(int number) {
    call(
        "reopen issue #" + number,
        () -> github.updateIssue(owner(), repo(), number, auth(), Map.of("state", "open")));
  }

  private JsonNode call(String what, Supplier<Response> request) {
    Response response;
    try {
      response = request.get();
    } catch (ProcessingException e) {
      throw new GitHubException("GitHub " + what + " failed: " + e.getMessage(), e);
    }
    try (response) {
      // Read as text: GitHub answers application/vnd.github+json, which not every reader claims.
      String body = response.hasEntity() ? response.readEntity(String.class) : "";
      if (response.getStatus() / 100 != 2) {
        throw new GitHubException(
            "GitHub " + what + " answered " + response.getStatus() + ": " + abbreviate(body));
      }
      return objectMapper.readTree(body.isEmpty() ? "{}" : body);
    } catch (JacksonException e) {
      throw new GitHubException("GitHub " + what + " answered unreadable JSON", e);
    }
  }

  private String owner() {
    if (owner == null) {
      throw new GitHubException("GitHub publication is not configured");
    }
    return owner;
  }

  private String repo() {
    if (repo == null) {
      throw new GitHubException("GitHub publication is not configured");
    }
    return repo;
  }

  private String auth() {
    return "Bearer " + token.orElseThrow();
  }

  private static String abbreviate(String s) {
    return s.length() <= 300 ? s : s.substring(0, 300) + "…";
  }
}

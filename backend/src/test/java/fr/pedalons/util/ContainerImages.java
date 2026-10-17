package fr.pedalons.util;

import static java.util.stream.Collectors.joining;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Resolves Docker image references for Testcontainers from sources that Dependabot already keeps up
 * to date, so test images never drift from the rest of the stack.
 *
 * <ul>
 *   <li>{@link #compose(String)} reads the {@code image:} tag from the deployment compose files
 *       (Dependabot {@code docker-compose} ecosystem). Paths are relative to the Maven basedir, so
 *       they climb out of {@code backend/} to the repository root.
 *   <li>{@link #s3mockVersion()} reads the version of the {@code s3mock-testcontainers} Maven
 *       dependency (Dependabot {@code maven} ecosystem), filtered into a classpath resource at build
 *       time. S3Mock has no docker-compose entry because production uses MinIO, not S3Mock.
 * </ul>
 */
public final class ContainerImages {

  // tileserver lives in the shared file, everything else in the environment one.
  private static final List<Path> COMPOSE_FILES =
      List.of(Path.of("../docker-compose.yml"), Path.of("../docker-compose.shared.yml"));
  private static final Pattern SERVICE = Pattern.compile("^ {2}([\\w-]+):\\s*$");
  private static final Pattern IMAGE = Pattern.compile("^\\s+image:\\s*(\\S+)\\s*$");

  private ContainerImages() {}

  /** Returns the {@code image:} value declared for {@code service} in the compose files. */
  public static String compose(String service) {
    for (Path file : COMPOSE_FILES) {
      String image = imageIn(file, service);
      if (image != null) {
        return image;
      }
    }
    throw new IllegalStateException(
        "No image found for service '" + service + "' in " + absolutePaths());
  }

  private static String imageIn(Path file, String service) {
    List<String> lines;
    try {
      lines = Files.readAllLines(file);
    } catch (IOException e) {
      throw new UncheckedIOException("Cannot read " + file.toAbsolutePath(), e);
    }
    boolean inService = false;
    for (String line : lines) {
      Matcher svc = SERVICE.matcher(line);
      if (svc.matches()) {
        inService = svc.group(1).equals(service);
        continue;
      }
      if (inService) {
        Matcher img = IMAGE.matcher(line);
        if (img.matches()) {
          return img.group(1);
        }
      }
    }
    return null;
  }

  private static String absolutePaths() {
    return COMPOSE_FILES.stream().map(p -> p.toAbsolutePath().toString()).collect(joining(", "));
  }

  /** Returns the S3Mock image version, matched to the s3mock-testcontainers Maven dependency. */
  public static String s3mockVersion() {
    try (InputStream in =
        ContainerImages.class.getResourceAsStream("/test-containers.properties")) {
      if (in == null) {
        throw new IllegalStateException("test-containers.properties not found on classpath");
      }
      Properties props = new Properties();
      props.load(in);
      String version = props.getProperty("s3mock.version");
      if (version == null || version.isBlank() || version.startsWith("$")) {
        throw new IllegalStateException(
            "s3mock.version was not filtered into test-containers.properties (got: "
                + version
                + ")");
      }
      return version;
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }
}

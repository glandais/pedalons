package fr.pedalons.infrastructure.http;

import io.quarkus.vertx.http.runtime.filters.Filters;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.jspecify.annotations.Nullable;

/**
 * Keeps the API out of search indexes: every {@code /api/*} response carries {@code X-Robots-Tag:
 * noindex}, except the public images.
 *
 * <p>Googlebot reaches API URLs through the React Query state serialised in the SSR HTML and
 * through links to public GPX/FIT files, and the Search Console then reports them as « Explorée,
 * non indexée » or « Page en double sans URL canonique ». {@code robots.txt} stops the crawl; this
 * header covers what is fetched anyway (a URL already known, a crawler that ignores robots.txt).
 *
 * <p><b>The public images stay indexable on purpose</b>: {@code og:image} / {@code twitter:image}
 * point at {@code /api/download/public/images/…} (see {@code frontend/src/lib/seo.ts}), and a
 * noindexed image is dropped from link previews and image search. Public assets ({@code
 * /api/download/public/assets/…}, GPX/FIT) get the header like the rest of the API. So do the
 * images of {@code PUBLIC_UNLISTED} content and the GPX preview thumbnails: their pages are
 * noindex, yet shared by link, so {@code robots.txt} lets crawlers fetch them for link previews,
 * which this header does not prevent.
 *
 * <p>A Vert.x filter rather than a JAX-RS {@code ContainerResponseFilter}: it also covers the
 * responses JAX-RS never produces — a path that matches no resource, a parameter that fails to
 * convert (a literal {@code {size}}), an error raised before a resource method runs.
 */
@ApplicationScoped
public class ApiNoIndexFilter {

  static final String HEADER = "X-Robots-Tag";
  static final String VALUE = "noindex";

  private static final String API_PREFIX = "/api/";
  private static final String PUBLIC_IMAGES_PREFIX = "/api/download/public/images/";

  /** Runs before the routes; the header is added once the response headers are final. */
  void register(@Observes Filters filters) {
    filters.register(
        rc -> {
          if (isNoIndex(rc.normalizedPath())) {
            rc.addHeadersEndHandler(v -> rc.response().headers().set(HEADER, VALUE));
          }
          rc.next();
        },
        // Above the default (0) so the end handler is registered whatever filter runs next.
        100);
  }

  /** {@code true} for every API path but the public images. */
  static boolean isNoIndex(@Nullable String path) {
    if (path == null) {
      return false;
    }
    boolean api = path.equals("/api") || path.startsWith(API_PREFIX);
    return api && !path.startsWith(PUBLIC_IMAGES_PREFIX);
  }
}

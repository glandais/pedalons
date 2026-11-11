package fr.pedalons.service.migration.live;

/**
 * Everything a running job needs, as plain values — no entity, no lazy proxy: the job spans many
 * short transactions and minutes of network and GPX work. Loaded once, when the job is claimed.
 *
 * @param attempt the attempt this run is; a progress write from a run that no longer owns the row
 *     (requeued as stuck, then reclaimed) is refused on it
 * @param baseUrl {@code domains.base_url} snapshotted at confirmation — never an alias
 */
public record LiveJobContext(
    long jobId,
    String jobTsid,
    long domainId,
    long userId,
    String biketeamTeamId,
    String requestId,
    String baseUrl,
    int attempt) {}

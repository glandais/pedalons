package fr.pedalons.dto.migration.internal;

/**
 * One element that did not make it, or made it with a caveat.
 *
 * @param entityType TEAM, TEAM_PAGE, PLACE, ROUTE, RIDE_TEMPLATE, PUBLICATION, RIDE, TRIP,
 *     TRIP_STAGE, IMAGE or LOGO
 * @param code GPX_MISSING, GPX_EMPTY, GPX_FAILURE, FILE_DOWNLOAD_FAILED, IMAGE_FAILED, ITEM_FAILED,
 *     TRIP_STAGES_OUTSIDE_DATES, TAGS_TRUNCATED or ROUTE_VISIBILITY_KEPT
 */
public record BiketeamJobWarningDto(
    String entityType, String biketeamId, String code, String message) {}

package fr.pedalons.dto.rides.response;

/**
 * What {@code switchGroup} answers (docs/LEDGER_*.md API-164): the registration, and whether the
 * resource says 201 or 200 — as {@code RideWeatherAnswer} carries the body and its {@code ETag}.
 *
 * @param participation the caller's registration in the group asked for
 * @param created false when the caller was already in that group: nothing was written
 */
public record RideSwitchAnswer(RideParticipationDto participation, boolean created) {}

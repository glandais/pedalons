package fr.pedalons.service.route.generator;

/** One-way status of an input edge, relative to the travel direction of the track. */
public enum Oneway {
  /** Two-way street. */
  BOTH,
  /** One-way street, ridden in its legal direction. */
  FORWARD,
  /** One-way street ridden against its direction: probably a contraflow bike lane. */
  AGAINST
}

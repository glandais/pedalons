package fr.pedalons.enums;

/**
 * Which elevation source a computation reads (a pipeline parameter; what is stored is an {@link
 * ElevationState}).
 *
 * <p>{@link #FAST} reads Mapterhorn only: a few tiles, a few seconds, no bridge decks. {@link #HD}
 * reads IGN LiDAR HD (Mapterhorn wherever IGN has no data) and rides bridge decks.
 */
public enum ElevationQuality {
  FAST,
  HD
}

package fr.pedalons.service.route.generator;

/** One of the eight compass directions a requested route should head towards. */
public enum Bearing8 {
  N(0),
  NE(45),
  E(90),
  SE(135),
  S(180),
  SW(225),
  W(270),
  NW(315);

  private final double degrees;

  Bearing8(double degrees) {
    this.degrees = degrees;
  }

  /** Compass bearing in degrees, 0 = north, clockwise. */
  public double degrees() {
    return degrees;
  }
}

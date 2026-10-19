import { describe, expect, it } from 'vitest'
import { decode1, decode2, encode1, encode2 } from './polyline'

describe('polyline', () => {
  it('writes the known string for one point', () => {
    expect(encode2([[-120.2, 38.5]])).toBe('_izlhA~rlgdF')
  })

  it('round-trips two dimensions at 1e-6', () => {
    const coords = [
      [4.835659, 45.764043],
      [4.841122, 45.77187],
      [-122.123456, -33.000001],
      [179.999999, 89.999999],
    ]
    const decoded = decode2(encode2(coords))
    expect(decoded).toHaveLength(coords.length)
    decoded.forEach((c, i) => {
      expect(c[0]).toBeCloseTo(coords[i][0], 6)
      expect(c[1]).toBeCloseTo(coords[i][1], 6)
    })
  })

  it('rounds to 1e-6 and ignores the elevation entry', () => {
    const [c] = decode2(encode2([[4.8356594999, 45.7640431111, 171.2, 33]]))
    expect(c[0]).toBeCloseTo(4.835659, 6)
    expect(c[1]).toBeCloseTo(45.764043, 6)
  })

  it('round-trips one dimension at a tenth of a metre, negatives included', () => {
    const values = [171.2, 171.24, 176, -12.5, 0, 1203.9]
    const decoded = decode1(encode1(values))
    expect(decoded).toEqual([171.2, 171.2, 176, -12.5, 0, 1203.9])
  })

  it('handles the empty string', () => {
    expect(encode2([])).toBe('')
    expect(decode2('')).toEqual([])
    expect(encode1([])).toBe('')
    expect(decode1('')).toEqual([])
  })

  it('refuses malformed strings', () => {
    expect(() => decode2(' ')).toThrow()
    expect(() => decode2('_')).toThrow() // truncated in the middle of a value
    expect(() => decode2('_p~iF')).toThrow() // a latitude without its longitude
    expect(() => decode1('_')).toThrow()
  })
})

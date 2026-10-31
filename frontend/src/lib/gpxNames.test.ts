import { describe, expect, it } from 'vitest'
import { defaultGpxName, gpxNameCandidates, parseGpxNames } from './gpxNames'

const gpx = (body: string) =>
  `<?xml version="1.0"?><gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">${body}</gpx>`
const trk = (name?: string, points = 2) =>
  `<trk>${name !== undefined ? `<name>${name}</name>` : ''}<trkseg>${'<trkpt lat="45" lon="6"><name>pt</name></trkpt>'.repeat(points)}</trkseg></trk>`

describe('parseGpxNames', () => {
  it('reads the metadata name, every track name and the file name', () => {
    const names = parseGpxNames(
      'export.GPX',
      gpx(`<metadata><name>Tour du lac</name></metadata>${trk('Aller')}${trk('Retour')}`)
    )
    expect(names).toEqual({
      fileName: 'export',
      documentName: 'Tour du lac',
      trackNames: ['Aller', 'Retour'],
    })
    expect(defaultGpxName(names)).toBe('Tour du lac')
    expect(gpxNameCandidates(names)).toEqual(['Tour du lac', 'Aller', 'Retour', 'export'])
  })

  it('falls back on the first non-empty track, then on the file name', () => {
    const tracks = parseGpxNames('a.gpx', gpx(`${trk('Vide', 0)}${trk('  ')}${trk('Col')}`))
    expect(tracks.trackNames).toEqual(['Col'])
    expect(defaultGpxName(tracks)).toBe('Col')

    const none = parseGpxNames('Sortie du dimanche.gpx', gpx(trk()))
    expect(defaultGpxName(none)).toBe('Sortie du dimanche')
    expect(gpxNameCandidates(none)).toEqual(['Sortie du dimanche'])
  })

  it('reads the routes (<rte>) as tracks, in file order', () => {
    const rte = (name: string, points = 2) =>
      `<rte><name>${name}</name>${'<rtept lat="45" lon="6"/>'.repeat(points)}</rte>`
    const names = parseGpxNames(
      'c.gpx',
      gpx(`${rte('Itinéraire')}${trk('Trace')}${rte('Vide', 0)}`)
    )
    expect(names.trackNames).toEqual(['Itinéraire', 'Trace'])
    expect(defaultGpxName(names)).toBe('Itinéraire')
  })

  it('reads a GPX 1.0 document name, never a point name', () => {
    const names = parseGpxNames('b.gpx', gpx(`<name>Doc</name>${trk()}`))
    expect(names.documentName).toBe('Doc')
    expect(names.trackNames).toEqual([])
  })

  it('keeps only the file name of an unreadable file', () => {
    const names = parseGpxNames('cassé.gpx', 'not xml <')
    expect(defaultGpxName(names)).toBe('cassé')
    expect(names.trackNames).toEqual([])
  })

  it('removes duplicates', () => {
    const names = parseGpxNames('Col.gpx', gpx(`${trk('Col')}${trk('Col')}`))
    expect(gpxNameCandidates(names)).toEqual(['Col'])
  })
})

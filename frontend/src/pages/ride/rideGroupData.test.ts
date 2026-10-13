import { describe, expect, it } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { paths } from '@/config/paths'
import { rideGroupDataRedirect } from './rideGroupData'

const g = (id: string) => ({ id, name: id }) as RideGroupDto

function redirect(groups: RideGroupDto[] | undefined, groupId = 'g1', search = '') {
  const queryClient = new QueryClient()
  if (groups) {
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      groups,
    } as unknown as RideDto)
  }
  return rideGroupDataRedirect(
    queryClient,
    { teamSlug: 'np', rideSlug: 'sortie', groupId },
    new URL(`https://pedalons.fr${paths.rideGroup('np', 'sortie', groupId)}${search}`)
  )
}

describe('rideGroupDataRedirect (WEB-79)', () => {
  it("sends a solo ride's group to the ride, with its query string", () => {
    expect(redirect([g('g1')], 'g1', '?q=x')).toBe(paths.ride('np', 'sortie') + '?q=x')
  })

  it('sends a group of a ride without groups to the ride', () => {
    expect(redirect([])).toBe(paths.ride('np', 'sortie'))
  })

  it('sends an unknown group of a solo ride to the ride', () => {
    expect(redirect([g('g1')], 'gone')).toBe(paths.ride('np', 'sortie'))
  })

  it('keeps the group page of a ride with several groups', () => {
    expect(redirect([g('g1'), g('g2')])).toBeUndefined()
    expect(redirect([g('g1'), g('g2')], 'gone')).toBeUndefined()
  })

  it('says nothing without the ride in the cache', () => {
    expect(redirect(undefined)).toBeUndefined()
  })
})

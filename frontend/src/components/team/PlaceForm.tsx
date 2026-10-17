import { useState } from 'react'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { TextInput, Checkbox, Stack, Group, Button, Text, Modal, Box } from '@mantine/core'
import {
  useCreatePlace,
  useUpdatePlace,
  getListPlacesQueryKey,
  getGetPlaceQueryKey,
} from '../../api/endpoints/places/places'
import { CreatePlaceBody } from '../../api/zod/places/places.zod'
import type { PlaceDetailDto, PlaceRequest, GeoJsonPoint } from '../../api/dto'
import { GeocoderAutocomplete } from '../common/GeocoderAutocomplete'

const validatePlace = zodFormValidator<PlaceRequest>(CreatePlaceBody)

// Address and link are optional, but the contract bounds them to 3+ characters when present — and
// a blank TextInput holds '', not undefined. Validated as-is, a new place (both seeded to '') kept
// « Ajouter » disabled with no error shown until both were filled. A blank field means "none".
const blankToUndefined = (value?: string) => (value?.trim() ? value : undefined)
const normalizePlace = (values: PlaceRequest): PlaceRequest => ({
  ...values,
  address: blankToUndefined(values.address),
  link: blankToUndefined(values.link),
})

interface PlaceFormProps {
  teamSlug: string
  place: PlaceDetailDto
  onClose: () => void
}

export function PlaceForm({ teamSlug, place, onClose }: PlaceFormProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const createMutation = useCreatePlace()
  const updateMutation = useUpdatePlace()

  const isEditing = place.id !== ''
  // A picked place whose position is still being looked up (docs/LEDGER_*.md API-129).
  const [geocoding, setGeocoding] = useState(false)

  const form = useForm<PlaceRequest>({
    validate: (values) => validatePlace(normalizePlace(values)),
    transformValues: normalizePlace,
    initialValues: place,
    validateInputOnChange: true,
  })

  const handleSubmit = (data: PlaceRequest) => {
    if (geocoding) return
    if (isEditing) {
      updateMutation.mutate(
        { teamSlug, placeId: place.id, data },
        {
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: getListPlacesQueryKey(teamSlug) })
            queryClient.invalidateQueries({ queryKey: getGetPlaceQueryKey(teamSlug, place.id) })
            notifications.show({
              message: i18next.t('teams.notifications.placeUpdated'),
              color: 'green',
            })
            onClose()
          },
        }
      )
    } else {
      createMutation.mutate(
        { teamSlug, data },
        {
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: getListPlacesQueryKey(teamSlug) })
            notifications.show({
              message: i18next.t('teams.notifications.placeCreated'),
              color: 'green',
            })
            onClose()
          },
        }
      )
    }
  }

  const mutation = isEditing ? updateMutation : createMutation

  return (
    <Modal
      opened={true}
      onClose={onClose}
      title={isEditing ? t('places.form.editTitle') : t('places.add')}
      size="md"
    >
      <form id="place-form" onSubmit={form.onSubmit(handleSubmit)}>
        <Stack>
          <TextInput
            label={
              <>
                {t('places.form.name.label')}{' '}
                <Text span c="red">
                  *
                </Text>
              </>
            }
            placeholder={t('places.form.name.placeholder')}
            {...form.getInputProps('name')}
          />

          <TextInput
            label={t('places.form.address.label')}
            placeholder={t('places.form.address.placeholder')}
            {...form.getInputProps('address')}
          />

          <TextInput
            label={t('places.form.link.label')}
            placeholder={t('places.form.link.placeholder')}
            type="url"
            {...form.getInputProps('link')}
          />

          <GeocoderAutocomplete
            value={form.values.geometry as GeoJsonPoint | null | undefined}
            onChange={(point) => form.setFieldValue('geometry', point ?? undefined)}
            label={t('geocoder.label')}
            disabled={mutation.isPending}
            onResolvingChange={setGeocoding}
          />

          <Group>
            <Checkbox
              label={t('places.form.startPlace')}
              {...form.getInputProps('startPlace', { type: 'checkbox' })}
            />
            <Checkbox
              label={t('places.form.endPlace')}
              {...form.getInputProps('endPlace', { type: 'checkbox' })}
            />
          </Group>
        </Stack>
      </form>
      <Box mt="md">
        <Button variant="default" onClick={onClose}>
          {t('actions.cancelAction')}
        </Button>
        <Button
          type="submit"
          form="place-form"
          disabled={mutation.isPending || geocoding || !form.isValid()}
          loading={mutation.isPending}
        >
          {isEditing ? t('actions.save') : t('places.form.create')}
        </Button>
      </Box>
    </Modal>
  )
}

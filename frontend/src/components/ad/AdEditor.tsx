import { useEffect, useMemo, useState } from 'react'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useTranslation } from 'react-i18next'
import { TextInput, Radio, Stack, Group, Button, Text, Select, NumberInput } from '@mantine/core'
import { AdRequest, AdType, RentalPeriod, GeoJsonPoint } from '@/api/dto'
import { CreateAdBody } from '@/api/zod/ads/ads.zod'
import { MediaEditor } from '../common/MediaEditor'
import { SlugEditor } from '../common/SlugEditor'
import { paths } from '@/config/paths'
import { GeocoderAutocomplete } from '../common/GeocoderAutocomplete'
import { TagPicker } from '@/components/tag'

interface AdEditorProps {
  teamSlug: string
  initialValues: AdRequest
  onSubmit: (data: AdRequest) => void | Promise<void>
  onCancel: () => void
  isPending: boolean
  submitButtonText?: string
  cancelButtonText?: string
  currentSlug?: string
  onSlugChange?: (newSlug: string) => Promise<void>
  canEditSlug?: boolean
}

export function AdEditor({
  teamSlug,
  initialValues,
  onSubmit,
  onCancel,
  isPending,
  submitButtonText,
  cancelButtonText,
  currentSlug,
  onSlugChange,
  canEditSlug = false,
}: AdEditorProps) {
  const { t } = useTranslation()
  // A picked place whose position is still being looked up (docs/LEDGER_*.md API-129).
  const [geocoding, setGeocoding] = useState(false)

  const adSchema = useMemo(
    () =>
      CreateAdBody.refine(
        (data) => {
          if (data.adType === AdType.RENTAL) {
            return data.rentalPeriod !== undefined
          }
          return true
        },
        {
          message: t('form.rentalPeriod.required'),
          path: ['rentalPeriod'],
        }
      ),
    [t]
  )

  const form = useForm<AdRequest>({
    validate: zodFormValidator<AdRequest>(adSchema),
    initialValues,
    validateInputOnChange: true,
  })

  const adType = form.values.adType

  useEffect(() => {
    form.validateField('rentalPeriod')
  }, [adType, form])

  const handleSubmit = (values: AdRequest) => {
    if (geocoding) return
    onSubmit(values)
  }

  return (
    <form onSubmit={form.onSubmit(handleSubmit)}>
      <Stack>
        <TextInput
          label={
            <>
              {t('form.title')}{' '}
              <Text span c="red">
                *
              </Text>
            </>
          }
          placeholder={t('ads.create.namePlaceholder')}
          {...form.getInputProps('name')}
        />

        {currentSlug && onSlugChange && (
          <SlugEditor
            currentSlug={currentSlug}
            baseUrl={paths.ad(teamSlug, '')}
            onSlugChange={onSlugChange}
            disabled={!canEditSlug}
          />
        )}

        <Radio.Group
          label={
            <>
              {t('ads.create.adTypeLabel')}{' '}
              <Text span c="red">
                *
              </Text>
            </>
          }
          {...form.getInputProps('adType')}
        >
          <Group mt="xs">
            <Radio value={AdType.SALE} label={t('ads.adType.SALE')} />
            <Radio value={AdType.RENTAL} label={t('ads.adType.RENTAL')} />
            <Radio value={AdType.WANTED} label={t('ads.adType.WANTED')} />
          </Group>
        </Radio.Group>

        <NumberInput
          label={t('ads.create.priceLabel')}
          description={t('ads.create.priceHint')}
          placeholder={t('ads.create.pricePlaceholder')}
          min={0}
          decimalScale={2}
          value={form.values.price ?? ''}
          onChange={(val) => form.setFieldValue('price', val === '' ? undefined : Number(val))}
          error={form.errors.price}
        />

        {adType === AdType.RENTAL && (
          <Select
            label={
              <>
                {t('ads.create.rentalPeriodLabel')}{' '}
                <Text span c="red">
                  *
                </Text>
              </>
            }
            placeholder={t('ads.create.rentalPeriodLabel')}
            data={[
              { value: RentalPeriod.DAY, label: t('ads.rentalPeriod.DAY') },
              { value: RentalPeriod.WEEK, label: t('ads.rentalPeriod.WEEK') },
              { value: RentalPeriod.MONTH, label: t('ads.rentalPeriod.MONTH') },
            ]}
            {...form.getInputProps('rentalPeriod')}
          />
        )}

        <Stack gap="xs">
          <Text size="sm" fw={500}>
            {t('form.description')}
          </Text>
          <MediaEditor
            value={form.values.media}
            onChange={(val) => form.setFieldValue('media', val)}
            placeholder={t('ads.create.descriptionPlaceholder')}
            minHeight="200px"
            maxHeight="400px"
            disabled={isPending}
            ariaLabel={t('form.description')}
            teamSlug={teamSlug}
          />
        </Stack>

        <TextInput
          label={t('ads.create.locationDescriptionLabel')}
          placeholder={t('ads.create.locationDescriptionPlaceholder')}
          {...form.getInputProps('locationDescription')}
        />

        <GeocoderAutocomplete
          value={form.values.locationGeometry as GeoJsonPoint | null | undefined}
          onChange={(point) => form.setFieldValue('locationGeometry', point ?? undefined)}
          label={t('geocoder.label')}
          disabled={isPending}
          onResolvingChange={setGeocoding}
        />

        <TagPicker
          teamSlug={teamSlug}
          type="AD"
          value={form.values.tagIds}
          onChange={(ids) => form.setFieldValue('tagIds', ids)}
          disabled={isPending}
        />

        <Radio.Group label={t('form.status')} {...form.getInputProps('status')}>
          <Stack gap="xs" mt="xs">
            <Radio value="DRAFT" label={t('status.DRAFT')} />
            <Radio value="PUBLISHED" label={t('status.PUBLISHED')} />
          </Stack>
        </Radio.Group>

        <Group justify="flex-end" pt="md">
          <Button variant="default" onClick={onCancel}>
            {cancelButtonText || t('actions.cancelAction')}
          </Button>
          <Button
            type="submit"
            disabled={isPending || geocoding || !form.isValid()}
            loading={isPending}
          >
            {submitButtonText || t('actions.save')}
          </Button>
        </Group>
      </Stack>
    </form>
  )
}

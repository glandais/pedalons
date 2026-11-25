import { useState, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { Stack, Paper, Group, Text, Button, ActionIcon, Image, Center } from '@mantine/core'
import { IconPaperclip, IconX, IconPlus, IconPhoto } from '@tabler/icons-react'
import { MediaDto, AssetDto } from '@/api/dto'
import { MarkdownEditor } from './MarkdownEditor'
import { uploadAsset } from '@/api/endpoints/assets/assets'
import { getImageSizeWidth } from '@/lib/assetMarkdown'

export interface MediaEditorProps {
  value: MediaDto
  onChange: (value: MediaDto) => void
  placeholder?: string
  minHeight?: string
  maxHeight?: string
  disabled?: boolean
  ariaLabel?: string
  teamSlug?: string
}

export function MediaEditor({
  value,
  onChange,
  placeholder,
  minHeight,
  maxHeight,
  disabled,
  ariaLabel,
  teamSlug,
}: MediaEditorProps) {
  const { t } = useTranslation()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const logoInputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState<string | null>(null)
  const [logoUploading, setLogoUploading] = useState(false)
  const [logoError, setLogoError] = useState<string | null>(null)
  const [imageUploading, setImageUploading] = useState(false)
  const [imageError, setImageError] = useState<string | null>(null)

  // Uploads resolve asynchronously, after `value` has possibly moved on. Reading the render-time
  // snapshot there would drop whatever was typed meanwhile — go through the latest value instead.
  const valueRef = useRef(value)
  valueRef.current = value

  const handleMarkdownChange = (markdown: string) => {
    onChange({ ...valueRef.current, markdown })
  }

  const handleImageUpload = async (
    file: File
  ): Promise<{ id: string; fileName: string } | null> => {
    if (!teamSlug) return null

    setImageUploading(true)
    setImageError(null)

    try {
      const asset = await uploadAsset(teamSlug, { file }, { assetType: 'IMAGE' })
      const current = valueRef.current
      onChange({
        ...current,
        assets: { ...current.assets, images: [...current.assets.images, asset] },
      })
      return { id: asset.id, fileName: asset.fileName }
    } catch {
      setImageError(t('error.loading'))
      return null
    } finally {
      setImageUploading(false)
    }
  }

  const handleLogoSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !teamSlug) return

    setLogoUploading(true)
    setLogoError(null)

    try {
      const asset = await uploadAsset(teamSlug, { file }, { assetType: 'LOGO' })
      const current = valueRef.current
      onChange({ ...current, assets: { ...current.assets, logo: asset } })
    } catch {
      setLogoError(t('error.loading'))
    } finally {
      setLogoUploading(false)
      if (logoInputRef.current) logoInputRef.current.value = ''
    }
  }

  const handleRemoveLogo = () => {
    onChange({ ...value, assets: { ...value.assets, logo: undefined } })
  }

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (!files || files.length === 0 || !teamSlug) return

    setUploading(true)
    setUploadError(null)

    const newAttachments: AssetDto[] = []
    try {
      for (const file of Array.from(files)) {
        const asset = await uploadAsset(teamSlug, { file }, { assetType: 'ATTACHMENT' })
        newAttachments.push(asset)
      }
      const current = valueRef.current
      onChange({
        ...current,
        assets: {
          ...current.assets,
          attachments: [...current.assets.attachments, ...newAttachments],
        },
      })
    } catch {
      // Add any successfully uploaded files before the error
      if (newAttachments.length > 0) {
        const current = valueRef.current
        onChange({
          ...current,
          assets: {
            ...current.assets,
            attachments: [...current.assets.attachments, ...newAttachments],
          },
        })
      }
      setUploadError(t('error.loading'))
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  const handleRemoveAttachment = (attachmentId: string) => {
    onChange({
      ...value,
      assets: {
        ...value.assets,
        attachments: value.assets.attachments.filter((a: AssetDto) => a.id !== attachmentId),
      },
    })
  }

  const attachments = value.assets.attachments
  const logo = value.assets.logo
  const canUpload = !!teamSlug && !disabled

  return (
    <Stack gap="sm">
      {teamSlug && (
        <Paper withBorder p="sm" bg="var(--mantine-color-body)">
          <Group gap="xs" mb="sm">
            <IconPhoto size={16} />
            <Text size="sm" fw={500}>
              {t('logo.title')}
            </Text>
          </Group>

          <Group>
            {logo?.imageUrl ? (
              <Image
                src={logo.imageUrl?.replace('{size}', String(getImageSizeWidth('thumbnail')))}
                alt={t('logo.title')}
                w={64}
                h={64}
                radius="md"
                fit="cover"
              />
            ) : (
              <Center
                w={64}
                h={64}
                style={{
                  border: '2px dashed var(--mantine-color-default-border)',
                  borderRadius: 'var(--mantine-radius-md)',
                }}
              >
                <IconPhoto size={32} color="var(--mantine-color-dimmed)" />
              </Center>
            )}

            <Group gap="xs">
              <input
                ref={logoInputRef}
                type="file"
                accept="image/*,.heic,.heif"
                onChange={handleLogoSelect}
                disabled={!canUpload || logoUploading}
                hidden
              />
              <Button
                variant="default"
                size="xs"
                onClick={() => logoInputRef.current?.click()}
                disabled={!canUpload || logoUploading}
                loading={logoUploading}
                leftSection={!logoUploading && !logo && <IconPlus size={14} />}
              >
                {logo ? t('logo.change') : t('logo.upload')}
              </Button>
              {logo && (
                <Button
                  variant="outline"
                  size="xs"
                  color="danger"
                  onClick={handleRemoveLogo}
                  disabled={disabled}
                  leftSection={<IconX size={14} />}
                >
                  {t('logo.remove')}
                </Button>
              )}
            </Group>
          </Group>

          {logoError && (
            <Text size="sm" c="red" mt="xs">
              {logoError}
            </Text>
          )}
        </Paper>
      )}

      <MarkdownEditor
        value={value.markdown}
        onChange={handleMarkdownChange}
        placeholder={placeholder}
        minHeight={minHeight}
        maxHeight={maxHeight}
        disabled={disabled}
        ariaLabel={ariaLabel}
        onImageUpload={teamSlug ? handleImageUpload : undefined}
        isUploadingImage={imageUploading}
        images={value.assets.images}
      />
      {imageError && (
        <Text size="sm" c="red">
          {imageError}
        </Text>
      )}

      {teamSlug && (
        <Paper withBorder p="sm" bg="var(--mantine-color-body)">
          <Group gap="xs" mb="sm">
            <IconPaperclip size={16} />
            <Text size="sm" fw={500}>
              {t('attachments.title')}
            </Text>
          </Group>

          {attachments.length > 0 && (
            <Stack gap="xs" mb="sm">
              {attachments.map((attachment: AssetDto) => {
                const thumbnailUrl = attachment.imageUrl?.replace(
                  '{size}',
                  String(getImageSizeWidth('thumbnail'))
                )
                return (
                  <Group
                    key={attachment.id}
                    justify="space-between"
                    p="xs"
                    bg="var(--mantine-color-default)"
                    style={{ borderRadius: 'var(--mantine-radius-sm)' }}
                  >
                    <Group gap="xs" style={{ flex: 1, minWidth: 0 }}>
                      {thumbnailUrl ? (
                        <Image
                          src={thumbnailUrl}
                          alt={attachment.fileName}
                          w={32}
                          h={32}
                          fit="cover"
                          radius="sm"
                        />
                      ) : (
                        <IconPaperclip size={14} color="var(--mantine-color-dimmed)" />
                      )}
                      <Text size="sm" truncate>
                        {attachment.fileName}
                      </Text>
                    </Group>
                    <ActionIcon
                      variant="subtle"
                      color="gray"
                      size="sm"
                      onClick={() => handleRemoveAttachment(attachment.id)}
                      disabled={disabled}
                      title={t('actions.delete')}
                      aria-label={t('actions.delete')}
                    >
                      <IconX size={14} />
                    </ActionIcon>
                  </Group>
                )
              })}
            </Stack>
          )}

          <input
            ref={fileInputRef}
            type="file"
            multiple
            onChange={handleFileSelect}
            disabled={!canUpload || uploading}
            hidden
          />
          <Button
            variant="default"
            size="xs"
            onClick={() => fileInputRef.current?.click()}
            disabled={!canUpload || uploading}
            loading={uploading}
            leftSection={!uploading && <IconPlus size={14} />}
          >
            {t('attachments.add')}
          </Button>

          {uploadError && (
            <Text size="sm" c="red" mt="xs">
              {uploadError}
            </Text>
          )}
        </Paper>
      )}
    </Stack>
  )
}

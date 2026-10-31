import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Text } from '@mantine/core'
import { IconUpload } from '@tabler/icons-react'
import { useQueryClient } from '@tanstack/react-query'
import { createRoute } from '@/api/endpoints/routes/routes'
import { SurfaceType, TeamDetailDto } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { defaultGpxName, readGpxNames } from '@/lib/gpxNames'

export interface UploadGpxFilesProps {
  team: TeamDetailDto
  disabled?: boolean
}

export function UploadGpxFiles({ team, disabled }: UploadGpxFilesProps) {
  const teamSlug = team.slug
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [progress, setProgress] = useState<{ current: number; total: number } | null>(null)
  const [error, setError] = useState<string | null>(null)

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (!files || files.length === 0) return

    setUploading(true)
    setError(null)
    setProgress({ current: 0, total: files.length })

    let successCount = 0
    const fileArray = Array.from(files)

    for (let i = 0; i < fileArray.length; i++) {
      const file = fileArray[i]
      // The file's own name (metadata, else first track), else its file name
      const name = defaultGpxName(await readGpxNames(file))

      try {
        await createRoute(teamSlug, {
          route: {
            name,
            visibility: team.visibility,
            surfaceType: SurfaceType.ROAD,
            media: defaultMedia(),
          },
          gpxFile: file,
        })
        successCount++
        setProgress({ current: i + 1, total: files.length })
      } catch {
        setError(t('error.loading'))
      }
    }

    setUploading(false)
    setProgress(null)

    if (successCount > 0) {
      // Refresh every cached view of this team's routes (list, detail, bulk).
      invalidateRouteQueries(queryClient, teamSlug)
    }

    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept=".gpx"
        multiple
        onChange={handleFileSelect}
        disabled={disabled || uploading}
        hidden
      />
      <Button
        variant="default"
        onClick={() => fileInputRef.current?.click()}
        disabled={disabled || uploading}
        loading={uploading}
        leftSection={!uploading && <IconUpload size={16} />}
      >
        {uploading && progress
          ? t('routes.upload.progress', { current: progress.current, total: progress.total })
          : t('routes.upload.button')}
      </Button>
      {error && (
        <Text size="sm" c="red">
          {error}
        </Text>
      )}
    </>
  )
}

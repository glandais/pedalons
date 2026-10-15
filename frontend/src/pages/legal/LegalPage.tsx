import type { ReactNode } from 'react'
import { Container, Title, Stack } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import { MarkdownDisplay } from '@/components/common/MarkdownDisplay'

import privacyFr from '@/assets/legal/privacy-policy.fr.md?raw'
import privacyEn from '@/assets/legal/privacy-policy.en.md?raw'
import termsFr from '@/assets/legal/terms-of-service.fr.md?raw'
import termsEn from '@/assets/legal/terms-of-service.en.md?raw'
import supportFr from '@/assets/legal/support.fr.md?raw'
import supportEn from '@/assets/legal/support.en.md?raw'

const content = {
  privacy: { fr: privacyFr, en: privacyEn },
  terms: { fr: termsFr, en: termsEn },
  support: { fr: supportFr, en: supportEn },
} as const

interface LegalPageProps {
  type: keyof typeof content
  /** Rendered between the title and the Markdown, which is also an asset of the mobile app. */
  beforeContent?: ReactNode
}

export function LegalPage({ type, beforeContent }: LegalPageProps) {
  const { t, i18n } = useTranslation()
  const lang = i18n.language.startsWith('fr') ? 'fr' : 'en'
  const markdown = content[type][lang]
  const titleKey = `legal.${type}.title` as const

  return (
    <Container size="md" py="xl">
      <Stack gap="md">
        <Title order={1}>{t(titleKey)}</Title>
        {beforeContent}
        <MarkdownDisplay markdown={markdown} />
      </Stack>
    </Container>
  )
}

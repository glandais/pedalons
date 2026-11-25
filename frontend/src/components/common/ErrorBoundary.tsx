import { Component, ErrorInfo, ReactNode } from 'react'
import { Translation } from 'react-i18next'
import {
  Alert,
  Button,
  Center,
  Paper,
  Stack,
  Text,
  Title,
  Code,
  Group,
  ThemeIcon,
} from '@mantine/core'
import { IconAlertTriangle, IconMessageReport, IconXboxX } from '@tabler/icons-react'
import { openFeedback } from '@/lib/feedback/feedbackStore'
import { reportError, toClientError } from '@/lib/feedback/errorReporter'
import { isStaleChunkError, reloadForStaleChunk } from '@/lib/staleChunk'
import { useAuthStore } from '@/store/authStore'

interface ErrorBoundaryProps {
  children: ReactNode
  fallback?: ReactNode
  onError?: (error: Error, errorInfo: ErrorInfo) => void
  /**
   * `page` (default) fills the viewport — for a whole route. `inline` stays inside
   * its slot, so a section that throws (a map, a chart) is replaced in place rather
   * than wiping the page around it.
   */
  variant?: 'page' | 'inline'
}

interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // A lazy route of a build replaced by a deploy: the reload fetches the new one.
    if (isStaleChunkError(error) && reloadForStaleChunk()) return
    console.error('ErrorBoundary caught an error:', error, errorInfo)
    reportError(error, errorInfo.componentStack ?? undefined)
    this.props.onError?.(error, errorInfo)
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null })
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback
      }

      return (
        <Translation ns="common">
          {(t) => (
            <Center
              // `dvh` for the same reason as `body` in index.css: on iOS `100vh` overshoots the
              // visible area by the browser chrome, making a full-page error screen scroll.
              mih={this.props.variant === 'inline' ? undefined : '100dvh'}
              py={this.props.variant === 'inline' ? 'xl' : undefined}
              bg="var(--mantine-color-body)"
            >
              <Paper
                shadow={this.props.variant === 'inline' ? 'xs' : 'lg'}
                withBorder={this.props.variant === 'inline'}
                p="xl"
                radius="md"
                w={{ base: '100%', sm: 400 }}
              >
                <Stack align="center">
                  <ThemeIcon size="xl" radius="xl" color="red" variant="light">
                    <IconAlertTriangle size={24} />
                  </ThemeIcon>
                  {/* The page variant replaces the whole route: its title is the page's h1, at the
                      size it had (docs/LEDGER_*.md WEB-210). */}
                  <Title order={this.props.variant === 'inline' ? 3 : 1} size="h3" ta="center">
                    {t('boundary.title')}
                  </Title>
                  <Text c="dimmed" ta="center">
                    {t('boundary.message')}
                  </Text>
                  {this.state.error && import.meta.env.DEV && (
                    <Code block color="red" w="100%">
                      {this.state.error.message}
                    </Code>
                  )}
                  <Group justify="center">
                    <Button onClick={this.handleRetry}>{t('boundary.retry')}</Button>
                    {this.props.variant !== 'inline' && (
                      <Button variant="default" onClick={() => window.location.reload()}>
                        {t('boundary.reload')}
                      </Button>
                    )}
                  </Group>
                  {/* The report needs a session; an anonymous visitor has the support page. */}
                  {useAuthStore.getState().isAuthenticated && (
                    <Button
                      variant="subtle"
                      leftSection={<IconMessageReport size={16} />}
                      onClick={() =>
                        openFeedback(this.state.error ? toClientError(this.state.error) : undefined)
                      }
                    >
                      {t('boundary.report')}
                    </Button>
                  )}
                </Stack>
              </Paper>
            </Center>
          )}
        </Translation>
      )
    }

    return this.props.children
  }
}

interface ErrorMessageProps {
  title?: string
  message: string
  onRetry?: () => void
}

export function ErrorMessage({ title, message, onRetry }: ErrorMessageProps) {
  return (
    <Translation ns="common">
      {(t) => (
        <Alert icon={<IconXboxX size={16} />} title={title || t('generic.title')} color="red">
          <Text size="sm">{message}</Text>
          {onRetry && (
            <Button variant="subtle" color="red" size="xs" mt="sm" onClick={onRetry}>
              {t('generic.retry')}
            </Button>
          )}
        </Alert>
      )}
    </Translation>
  )
}

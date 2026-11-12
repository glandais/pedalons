import {
  TextInput,
  Box,
  CloseButton,
  type MantineStyleProp,
  type MantineSpacing,
} from '@mantine/core'
import { IconSearch } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'

export interface SearchInputProps {
  value: string
  onChange: (value: string) => void
  placeholder: string
  label?: string
  id?: string
  fullWidth?: boolean
  style?: MantineStyleProp
  mb?: MantineSpacing
}

export function SearchInput({
  value,
  onChange,
  placeholder,
  label,
  id = 'search',
  fullWidth = false,
  style,
  mb,
}: SearchInputProps) {
  const { t } = useTranslation()
  return (
    <Box w={fullWidth ? '100%' : { base: '100%', sm: 320 }} style={style} mb={mb}>
      <TextInput
        id={id}
        type="search"
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.currentTarget.value)}
        aria-label={label || placeholder}
        leftSection={<IconSearch size={16} />}
        rightSection={
          value && (
            <CloseButton
              size="sm"
              aria-label={t('common.clearSearch')}
              onClick={() => onChange('')}
            />
          )
        }
      />
    </Box>
  )
}

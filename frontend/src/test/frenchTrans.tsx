import { Fragment, type ReactElement } from 'react'
import { frenchT } from './frenchT'

/**
 * A `<Trans>` reading the French catalogue, for tests that mock `react-i18next` with `frenchT`:
 * only self-closing components (`<arrow/>`), the form the weather strings use.
 */
export function FrenchTrans({
  i18nKey,
  values,
  components = {},
}: {
  i18nKey: string
  values?: Record<string, unknown>
  components?: Record<string, ReactElement>
}) {
  const parts = frenchT(i18nKey, values).split(/<(\w+)\/>/)
  return (
    <>
      {parts.map((part, i) => (
        <Fragment key={i}>{i % 2 === 1 ? components[part] : part}</Fragment>
      ))}
    </>
  )
}

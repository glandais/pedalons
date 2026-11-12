import { Fragment } from 'react'
import { Anchor } from '@mantine/core'
import { splitPlainTextLinks } from '@/utils/plainTextLinks'

/**
 * Raw text whose full web addresses are links, opened in a new tab and shown whole (KIT §9,
 * 2026-11-12): a comment. Nothing else in the text is interpreted. `nofollow`: the address is a
 * member's, not the site's recommendation.
 */
export function PlainTextWithLinks({ text }: { text: string }) {
  return (
    <>
      {splitPlainTextLinks(text).map((part, index) =>
        part.kind === 'link' ? (
          <Anchor
            key={index}
            href={part.href}
            target="_blank"
            rel="noopener noreferrer nofollow"
            inherit
            style={{ wordBreak: 'break-all' }}
          >
            {part.href}
          </Anchor>
        ) : (
          <Fragment key={index}>{part.text}</Fragment>
        )
      )}
    </>
  )
}

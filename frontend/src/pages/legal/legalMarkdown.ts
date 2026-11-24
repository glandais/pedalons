/**
 * Drops a leading `# Title` line from a legal text before it is displayed: the page already renders
 * that title as its own `<h1>`, and the Markdown files (`privacy/*.md`, copied to
 * `src/assets/legal/` by `pnpm copy-legal`) are shared with the mobile app, so they keep their
 * heading. Only a level-1 heading on the first non-blank line goes; a `##` or body text stays.
 */
export function stripLeadingTitle(markdown: string): string {
  return markdown.replace(
    /^(?:[ \t]*\r?\n)*[ \t]{0,3}#[ \t]+[^\r\n]*(?:\r?\n|$)(?:[ \t]*\r?\n)*/,
    ''
  )
}

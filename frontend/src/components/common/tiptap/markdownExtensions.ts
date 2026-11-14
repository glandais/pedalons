import type { AnyExtension } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import { Table } from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableHeader from '@tiptap/extension-table-header'
import TableCell from '@tiptap/extension-table-cell'
import Placeholder from '@tiptap/extension-placeholder'
import { Markdown } from 'tiptap-markdown'

/**
 * The extensions that decide which markdown an editor reads and writes, `::asset{}` aside (each
 * editor adds its own view of `AssetNodeBase`).
 *
 * The site's editor and the one the mobile app embeds both take them from here: a schema or a
 * serializer option that differs between the two would have one client rewrite what the other
 * wrote, every time a member opens the text.
 */
export function markdownEditorExtensions(options: {
  /** A function is read at each render, for a text the embedder only knows later. */
  placeholder: string | (() => string)
  resizableTables: boolean
}): AnyExtension[] {
  return [
    StarterKit.configure({
      // Disable code block (not in original editor)
      codeBlock: false,
    }),
    Table.configure({ resizable: options.resizableTables }),
    TableRow,
    TableHeader,
    TableCell,
    Placeholder.configure({ placeholder: options.placeholder }),
    Markdown.configure({
      // html: true is needed to parse <div data-type="asset"> tags from markdownToEditor()
      html: true,
      tightLists: true,
      bulletListMarker: '-',
    }),
  ]
}

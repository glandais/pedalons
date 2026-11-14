import { Node, mergeAttributes } from '@tiptap/core'
import { createAssetDirective, DEFAULT_IMAGE_SIZE, type ImageSize } from '@/lib/assetMarkdown'

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    asset: {
      insertAsset: (attrs: { id: string; alt?: string; size?: string }) => ReturnType
    }
  }
}

export interface AssetNodeOptions {
  HTMLAttributes: Record<string, unknown>
}

/**
 * The `::asset{}` node without its view: schema, commands and markdown serialization.
 *
 * Shared by the site's editor (which adds a React view, `AssetNode`) and the editor the mobile app
 * embeds in a WebView (`src/embed/mobile-editor`, a DOM view). Both must write the very same
 * directive, so neither may redefine `addStorage`.
 */
export const AssetNodeBase = Node.create<AssetNodeOptions>({
  name: 'asset',
  group: 'block',
  atom: true,
  draggable: true,

  addOptions() {
    return {
      HTMLAttributes: {},
    }
  },

  addAttributes() {
    return {
      id: {
        default: null,
        parseHTML: (element: HTMLElement) =>
          element.getAttribute('data-id') || element.getAttribute('id'),
        renderHTML: (attributes: Record<string, unknown>) => ({ 'data-id': attributes.id }),
      },
      size: {
        default: DEFAULT_IMAGE_SIZE,
        parseHTML: (element: HTMLElement) =>
          element.getAttribute('data-size') || element.getAttribute('size') || DEFAULT_IMAGE_SIZE,
        renderHTML: (attributes: Record<string, unknown>) => ({ 'data-size': attributes.size }),
      },
      alt: {
        default: '',
        parseHTML: (element: HTMLElement) =>
          element.getAttribute('data-alt') || element.getAttribute('alt') || '',
        renderHTML: (attributes: Record<string, unknown>) => ({ 'data-alt': attributes.alt }),
      },
    }
  },

  parseHTML() {
    return [
      {
        // Match <div data-type="asset" ...>
        tag: 'div[data-type="asset"]',
      },
    ]
  },

  renderHTML({ HTMLAttributes }: { HTMLAttributes: Record<string, unknown> }) {
    return [
      'div',
      mergeAttributes(this.options.HTMLAttributes, HTMLAttributes, { 'data-type': 'asset' }),
    ]
  },

  addCommands() {
    return {
      insertAsset:
        (attrs: { id: string; alt?: string; size?: string }) =>
        ({ commands }) => {
          return commands.insertContent({
            type: this.name,
            attrs,
          })
        },
    }
  },

  addStorage() {
    return {
      markdown: {
        serialize(
          state: { write: (text: string) => void },
          node: { attrs: Record<string, unknown> }
        ) {
          const directive = createAssetDirective(
            String(node.attrs.id),
            node.attrs.alt ? String(node.attrs.alt) : '',
            node.attrs.size as ImageSize | undefined
          )
          state.write(`${directive}\n\n`)
        },
        parse: {
          // Parsing handled via pre-processing with markdownToEditor()
        },
      },
    }
  },
})

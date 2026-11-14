/**
 * The site's markdown editor, without React, for the mobile app to embed in a WebView.
 *
 * Built by `pnpm build:mobile-editor` into `mobile/assets/editor/`. The schema and the markdown
 * serializer are the site's own (`markdownEditorExtensions`, `AssetNodeBase`, `markdownToEditor`):
 * the app writes exactly the markdown the site writes, so neither client rewrites the other's text.
 *
 * The page knows no token and no URL: Flutter drives it through `window.pedalons` and hears back on
 * the `PedalonsBridge` JavaScript channel. Images come back as data URLs fetched by the app with its
 * own credentials.
 */
import './editor.css'
import { Editor } from '@tiptap/core'
import { NodeSelection, Selection, TextSelection } from '@tiptap/pm/state'
import { AssetNodeBase } from '@/components/common/tiptap/AssetNodeBase'
import { markdownEditorExtensions } from '@/components/common/tiptap/markdownExtensions'
import { markdownToEditor } from '@/components/common/tiptap/markdownUtils'
import {
  ASSET_DIRECTIVE_REGEX,
  getImageSizeWidth,
  parseAssetDirective,
  parseDirectiveAttributes,
  type ImageSize,
} from '@/lib/assetMarkdown'

type AssetRef = { id: string; imageUrl?: string | null; url?: string | null }

type Theme = {
  text: string
  muted: string
  background: string
  border: string
  accent: string
  surface: string
  fontSize: number
}

type Outgoing =
  | { type: 'ready' }
  | { type: 'change'; markdown: string }
  | { type: 'state'; active: Record<string, boolean>; focused: boolean }
  | { type: 'image'; key: string; url: string }

declare global {
  interface Window {
    PedalonsBridge?: { postMessage(message: string): void }
    pedalons: PedalonsEditorApi
  }
}

const post = (message: Outgoing) => window.PedalonsBridge?.postMessage(JSON.stringify(message))

// ── Images ──────────────────────────────────────────────────────────────────────────────────────

let assets: AssetRef[] = []
const imageCache = new Map<string, string>()
const waiting = new Map<string, HTMLImageElement[]>()
let unresolved: { img: HTMLImageElement; assetId: string; size: ImageSize }[] = []

function requestImage(img: HTMLImageElement, assetId: string, size: ImageSize) {
  const asset = assets.find((a) => a.id === assetId)
  const url = asset?.imageUrl
    ? asset.imageUrl.replace('{size}', String(getImageSizeWidth(size)))
    : asset?.url
  if (!url) {
    // An image just uploaded: the app inserts its directive before handing over the new image
    // list (`setImages`), which retries it.
    unresolved.push({ img, assetId, size })
    return
  }
  const key = `${assetId}@${size}`
  const cached = imageCache.get(key)
  if (cached) {
    img.src = cached
    return
  }
  const list = waiting.get(key) ?? []
  list.push(img)
  waiting.set(key, list)
  if (list.length === 1) post({ type: 'image', key, url })
}

/** The shared `::asset{}` node, drawn as a plain `<figure>`. */
const AssetNode = AssetNodeBase.extend({
  addNodeView() {
    return ({ node }) => {
      const dom = document.createElement('figure')
      dom.className = `asset asset-${String(node.attrs.size)}`
      dom.contentEditable = 'false'
      const img = document.createElement('img')
      img.alt = String(node.attrs.alt ?? '')
      img.draggable = false
      dom.appendChild(img)
      requestImage(img, String(node.attrs.id), node.attrs.size as ImageSize)
      return { dom }
    }
  },
})

// ── Editor ──────────────────────────────────────────────────────────────────────────────────────

let lastEmitted = ''
let loaded = false
let placeholderText = ''

const editor = new Editor({
  element: document.getElementById('editor')!,
  extensions: [
    ...markdownEditorExtensions({ placeholder: () => placeholderText, resizableTables: false }),
    AssetNode,
  ],
  editorProps: {
    // A selected image (one tap on it) is not replaced by typing: the text goes into a new
    // paragraph right after it.
    handleTextInput(view, _from, _to, text) {
      const { selection, schema, storedMarks } = view.state
      if (!(selection instanceof NodeSelection) || selection.node.type.name !== 'asset') {
        return false
      }
      const paragraph = schema.nodes.paragraph.create(
        null,
        schema.text(text, storedMarks ?? undefined)
      )
      const tr = view.state.tr.insert(selection.to, paragraph)
      tr.setSelection(TextSelection.create(tr.doc, selection.to + 1 + text.length))
      view.dispatch(tr.scrollIntoView())
      return true
    },
  },
})

const getMarkdown = (): string =>
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (editor.storage as any).markdown.getMarkdown()

editor.on('update', () => {
  // Every edit, not debounced: the app's form reads its controller when « Enregistrer » is tapped,
  // and a pending debounce would lose the last keystrokes.
  lastEmitted = getMarkdown()
  post({ type: 'change', markdown: lastEmitted })
})

const STATE_NAMES = ['bold', 'italic', 'strike', 'bulletList', 'orderedList', 'blockquote', 'link']
function sendState() {
  const active: Record<string, boolean> = {}
  for (const name of STATE_NAMES) active[name] = editor.isActive(name)
  active.heading = editor.isActive('heading', { level: 2 })
  post({ type: 'state', active, focused: editor.isFocused })
}
editor.on('transaction', sendState)
editor.on('focus', sendState)
editor.on('blur', sendState)

/**
 * The toolbar's buttons target text. Outside of it (an image selected, an editor never touched,
 * whose selection then sits on the last node), the caret first goes to the nearest text after the
 * selection — otherwise bold would apply to nothing and the next keystroke replace the image.
 */
function ensureTextCaret() {
  const { selection, doc } = editor.state
  if (selection instanceof TextSelection) return
  const near = Selection.near(doc.resolve(selection.to), 1)
  if (near instanceof TextSelection) editor.commands.setTextSelection(near.from)
  else editor.commands.insertContentAt(selection.to, { type: 'paragraph' })
}

function applyTheme(theme: Theme) {
  const root = document.documentElement.style
  root.setProperty('--text', theme.text)
  root.setProperty('--muted', theme.muted)
  root.setProperty('--background', theme.background)
  root.setProperty('--border', theme.border)
  root.setProperty('--accent', theme.accent)
  root.setProperty('--surface', theme.surface)
  root.setProperty('--font-size', `${theme.fontSize}px`)
}

const api = {
  /** Replaces the whole text — the first load, or a change made outside the editor. */
  load(markdown: string, images: AssetRef[], placeholder: string, theme: Theme | null) {
    assets = images
    if (theme) applyTheme(theme)
    placeholderText = placeholder
    // The text this editor just wrote, coming back through the app's controller.
    if (loaded && markdown === lastEmitted) return
    loaded = true
    lastEmitted = markdown
    editor.commands.setContent(markdownToEditor(markdown), { emitUpdate: false })
  },
  /** The text's images changed (one uploaded): only the lookup table, never the text. */
  setImages(images: AssetRef[]) {
    assets = images
    const retry = unresolved.filter((u) => u.img.isConnected)
    unresolved = []
    for (const u of retry) requestImage(u.img, u.assetId, u.size)
  },
  image(key: string, dataUrl: string) {
    imageCache.set(key, dataUrl)
    for (const img of waiting.get(key) ?? []) img.src = dataUrl
    waiting.delete(key)
  },
  setEditable(editable: boolean) {
    editor.setEditable(editable)
  },
  /** Inserts what the app's image action returned: one `::asset{}` directive. */
  insertDirective(directive: string) {
    const match = new RegExp(ASSET_DIRECTIVE_REGEX.source).exec(directive)
    const parsed = match ? parseAssetDirective(parseDirectiveAttributes(match[1])) : null
    if (!parsed) return
    ensureTextCaret()
    editor
      .chain()
      .focus()
      .insertAsset({ id: parsed.assetId, alt: parsed.alt, size: parsed.size })
      .run()
  },
  setLink(url: string, label: string) {
    ensureTextCaret()
    const { empty } = editor.state.selection
    const chain = editor.chain().focus()
    if (empty) {
      chain
        .insertContent({
          type: 'text',
          text: label || url,
          marks: [{ type: 'link', attrs: { href: url } }],
        })
        .run()
    } else {
      chain.extendMarkRange('link').setLink({ href: url }).run()
    }
  },
  cmd(name: string) {
    if (name !== 'undo' && name !== 'redo') ensureTextCaret()
    const chain = editor.chain().focus()
    switch (name) {
      case 'bold':
        return chain.toggleBold().run()
      case 'italic':
        return chain.toggleItalic().run()
      case 'strike':
        return chain.toggleStrike().run()
      case 'heading':
        return chain.toggleHeading({ level: 2 }).run()
      case 'bulletList':
        return chain.toggleBulletList().run()
      case 'orderedList':
        return chain.toggleOrderedList().run()
      case 'blockquote':
        return chain.toggleBlockquote().run()
      case 'table':
        return chain.insertTable({ rows: 3, cols: 2, withHeaderRow: true }).run()
      case 'undo':
        return chain.undo().run()
      case 'redo':
        return chain.redo().run()
    }
    return false
  },
  blur() {
    editor.commands.blur()
  },
}

export type PedalonsEditorApi = typeof api

window.pedalons = api
post({ type: 'ready' })

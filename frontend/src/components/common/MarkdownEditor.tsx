import { useCallback, useEffect, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { Box } from '@mantine/core'
import { RichTextEditor } from '@mantine/tiptap'
import { useEditor, type Editor } from '@tiptap/react'
import type { EditorView } from '@tiptap/pm/view'
import '@mantine/tiptap/styles.css'

import type { AssetDto } from '@/api/dto'
import {
  AssetNode,
  AssetImagesProvider,
  markdownToEditor,
  markdownEditorExtensions,
  ImageUploadControl,
  imageFiles,
  uploadAndInsert,
  type ImageUploadHandler,
} from './tiptap'
import './tiptap/tiptap.css'

// Debounce utility
function debounce(
  fn: (value: string) => void,
  delay: number
): ((value: string) => void) & { flush: () => void; cancel: () => void } {
  let timeoutId: ReturnType<typeof setTimeout> | null = null
  let pending: { value: string } | null = null
  const run = () => {
    timeoutId = null
    const queued = pending
    pending = null
    if (queued) fn(queued.value)
  }
  const debounced = (value: string) => {
    if (timeoutId) clearTimeout(timeoutId)
    pending = { value }
    timeoutId = setTimeout(run, delay)
  }
  // Runs the pending call now, if any — a no-op when nothing is queued.
  debounced.flush = () => {
    if (timeoutId) clearTimeout(timeoutId)
    run()
  }
  // Drops the pending call, if any.
  debounced.cancel = () => {
    if (timeoutId) clearTimeout(timeoutId)
    timeoutId = null
    pending = null
  }
  return debounced
}

export interface MarkdownEditorProps {
  value: string
  onChange?: (value: string) => void
  placeholder?: string
  minHeight?: string
  maxHeight?: string
  disabled?: boolean
  ariaLabel?: string
  onImageUpload?: ImageUploadHandler
  isUploadingImage?: boolean
  images?: AssetDto[]
}

export function MarkdownEditor({
  value = '',
  onChange,
  placeholder,
  minHeight = '200px',
  maxHeight = '1024px',
  disabled = false,
  ariaLabel,
  onImageUpload,
  isUploadingImage,
  images = [],
}: MarkdownEditorProps) {
  const { t } = useTranslation()

  // The debounced writer must never capture `onChange`: the parent rebuilds that callback on every
  // render, over a `value` snapshot taken at that render. An image upload writes `assets` first and
  // only then inserts the node, so a debounce holding the pre-upload callback fires 150 ms later and
  // writes the stale `assets` back — markdown pointing at one asset, `assets.images` at another.
  // Going through a ref keeps a single timer that always calls the freshest callback.
  const onChangeRef = useRef(onChange)
  useEffect(() => {
    onChangeRef.current = onChange
  }, [onChange])

  // Last markdown this editor produced. The value coming back down after our own edit is not an
  // external change, and re-applying it with setContent would drop the node we just inserted.
  const lastEmitted = useRef(value)
  // True between an editor edit and the moment the debounce hands it to the parent. During that
  // window `value` is one edit behind on purpose — an image upload re-renders the parent inside it
  // (it writes `assets` immediately) and the stale markdown must not be pushed back into the editor.
  const hasPendingEdit = useRef(false)

  // Debounced onChange to avoid performance issues during typing
  const debouncedOnChange = useMemo(
    () =>
      debounce((markdown: string) => {
        hasPendingEdit.current = false
        onChangeRef.current?.(markdown)
      }, 150),
    []
  )

  // Flushed on blur: whatever sits in the debounce is text the user typed, and the form only learns
  // about it when the timer fires. Clicking « Enregistrer » blurs the editor first, so the markdown
  // reaches the form before the button's click handler reads it.
  //
  // Cancelled — not flushed — on unmount: an editor unmounts because its owner went away (a trip
  // stage deleted from its list), and writing to `stages.1.media` once stage 1 is gone throws
  // inside `setFieldValue` and takes the whole page down.
  useEffect(() => () => debouncedOnChange.cancel(), [debouncedOnChange])

  const handleEditorChange = useCallback(
    (markdown: string) => {
      lastEmitted.current = markdown
      hasPendingEdit.current = true
      debouncedOnChange(markdown)
    },
    [debouncedOnChange]
  )

  // The drop and paste handlers are fixed when the editor is created; they read the upload handler
  // and the editor through refs, for the same reason as onChangeRef above.
  const onImageUploadRef = useRef(onImageUpload)
  useEffect(() => {
    onImageUploadRef.current = onImageUpload
  }, [onImageUpload])
  const editorRef = useRef<Editor | null>(null)

  /**
   * Image files dropped or pasted into the text go through the same upload as the toolbar button.
   * False — let ProseMirror handle the event — when there is no image, no upload (an editor without
   * a team), or the editor is read-only.
   */
  const uploadFiles = (view: EditorView, files: FileList | null | undefined, pos: number) => {
    const upload = onImageUploadRef.current
    const current = editorRef.current
    const images = imageFiles(files)
    if (!upload || !current || !view.editable || images.length === 0) return false
    void uploadAndInsert(current, pos, images, upload)
    return true
  }

  const editor = useEditor({
    extensions: [
      ...markdownEditorExtensions({
        placeholder: placeholder || t('editor.placeholder'),
        resizableTables: true,
      }),
      AssetNode,
    ],
    content: markdownToEditor(value),
    editable: !disabled,
    // The contenteditable is the field itself: without these a screen reader announces an unnamed
    // editable region.
    editorProps: {
      attributes: {
        role: 'textbox',
        'aria-multiline': 'true',
        ...(ariaLabel ? { 'aria-label': ariaLabel } : {}),
      },
      handleDrop: (view, event, _slice, moved) => {
        // `moved` is a drag inside the editor (an image being repositioned), not a file.
        if (moved) return false
        const at = view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos
        const handled = uploadFiles(view, event.dataTransfer?.files, at ?? view.state.selection.to)
        if (handled) event.preventDefault()
        return handled
      },
      handlePaste: (view, event) =>
        uploadFiles(view, event.clipboardData?.files, view.state.selection.to),
    },
    onBlur: () => debouncedOnChange.flush(),
    onUpdate: ({ editor }) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const storage = editor.storage as any
      const markdown = storage.markdown?.getMarkdown?.() || ''
      handleEditorChange(markdown)
    },
  })

  useEffect(() => {
    editorRef.current = editor
  }, [editor])

  // Sync external value changes to editor
  useEffect(() => {
    if (!editor || editor.isDestroyed) return
    // Our own edit echoing back — the editor already holds it.
    if (value === lastEmitted.current) return
    // An edit of ours is still queued; `value` predates it.
    if (hasPendingEdit.current) return
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const storage = editor.storage as any
    const currentMarkdown = storage.markdown?.getMarkdown?.() || ''
    if (value === currentMarkdown) return
    lastEmitted.current = value
    editor.commands.setContent(markdownToEditor(value), { emitUpdate: false })
  }, [value, editor, debouncedOnChange])

  // Update editable state when disabled changes
  useEffect(() => {
    if (editor && !editor.isDestroyed) {
      editor.setEditable(!disabled)
    }
  }, [disabled, editor])

  return (
    <AssetImagesProvider images={images}>
      <Box
        className="tiptap-editor"
        style={
          {
            '--tiptap-min-height': minHeight,
            '--tiptap-max-height': maxHeight,
          } as React.CSSProperties
        }
      >
        <RichTextEditor
          editor={editor}
          styles={{
            root: {
              border: '1px solid var(--mantine-color-default-border)',
              borderRadius: 'var(--mantine-radius-xl)',
              boxShadow: 'var(--mantine-shadow-sm)',
              backgroundColor: 'var(--mantine-color-body)',
            },
            toolbar: {
              backgroundColor: 'var(--mantine-color-default-hover)',
              borderBottom: '1px solid var(--mantine-color-default-border)',
              borderRadius: 'var(--mantine-radius-xl) var(--mantine-radius-xl) 0 0',
            },
            // The content box reserves its height inline, NOT from `tiptap.css`. Two independent
            // things arrive after the first paint: the editor itself (`useEditor` returns null
            // until it is created, so there is no `.ProseMirror` in the DOM) and the page chunk's
            // stylesheet. With the min-height in the stylesheet, either one missing collapses the
            // zone to 0 px — measured: 150 px with the rule, 0 px without it. An inline style is
            // part of the markup, so the box is the right size from the very first frame.
            content: {
              borderRadius: '0 0 var(--mantine-radius-xl) var(--mantine-radius-xl)',
              minHeight,
              maxHeight,
              overflowY: 'auto',
              resize: 'vertical',
            },
          }}
        >
          <RichTextEditor.Toolbar sticky stickyOffset={0}>
            <RichTextEditor.ControlsGroup>
              <RichTextEditor.Undo />
              <RichTextEditor.Redo />
            </RichTextEditor.ControlsGroup>

            <RichTextEditor.ControlsGroup>
              <RichTextEditor.Bold />
              <RichTextEditor.Italic />
            </RichTextEditor.ControlsGroup>

            <RichTextEditor.ControlsGroup>
              <RichTextEditor.H1 />
              <RichTextEditor.H2 />
              <RichTextEditor.H3 />
            </RichTextEditor.ControlsGroup>

            <RichTextEditor.ControlsGroup>
              <RichTextEditor.BulletList />
              <RichTextEditor.OrderedList />
            </RichTextEditor.ControlsGroup>

            <RichTextEditor.ControlsGroup>
              <RichTextEditor.Link />
              <RichTextEditor.Unlink />
            </RichTextEditor.ControlsGroup>

            <RichTextEditor.ControlsGroup>
              <RichTextEditor.Blockquote />
              <RichTextEditor.Hr />
            </RichTextEditor.ControlsGroup>

            {onImageUpload && (
              <RichTextEditor.ControlsGroup>
                <ImageUploadControl onImageUpload={onImageUpload} isUploading={isUploadingImage} />
              </RichTextEditor.ControlsGroup>
            )}
          </RichTextEditor.Toolbar>

          <RichTextEditor.Content />
        </RichTextEditor>
      </Box>
    </AssetImagesProvider>
  )
}

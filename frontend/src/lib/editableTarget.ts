/**
 * True when a keyboard event's target is somewhere the user types: an input, a textarea, a select
 * or a contenteditable element. Global shortcuts (the "h" key, Ctrl+Z) must stay silent there so
 * they never steal the field's own behaviour (typing, the browser's native text undo).
 */
export function isEditableTarget(target: EventTarget | null): boolean {
  if (!target) return false
  const el = target as HTMLElement
  if (el.isContentEditable) return true
  // jsdom does not implement isContentEditable: fall back on the attribute.
  const attr = typeof el.getAttribute === 'function' ? el.getAttribute('contenteditable') : null
  if (attr !== null && attr !== 'false') return true
  return el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT'
}

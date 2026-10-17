import { describe, expect, it } from 'vitest'
import { isEditableTarget } from './editableTarget'

describe('isEditableTarget', () => {
  it('is true for input, textarea and select', () => {
    for (const tag of ['input', 'textarea', 'select']) {
      expect(isEditableTarget(document.createElement(tag))).toBe(true)
    }
  })

  it('is true for a contenteditable element', () => {
    const div = document.createElement('div')
    div.setAttribute('contenteditable', 'true')
    expect(isEditableTarget(div)).toBe(true)
  })

  it('is false for a contenteditable="false" element, a plain element and null', () => {
    const div = document.createElement('div')
    div.setAttribute('contenteditable', 'false')
    expect(isEditableTarget(div)).toBe(false)
    expect(isEditableTarget(document.createElement('button'))).toBe(false)
    expect(isEditableTarget(null)).toBe(false)
  })

  it('is false for a non-element target such as window', () => {
    expect(isEditableTarget(window)).toBe(false)
  })
})

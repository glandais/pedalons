import { ReactNodeViewRenderer } from '@tiptap/react'
import { AssetNodeBase } from './AssetNodeBase'
import { AssetNodeView } from './AssetNodeView'

export type { AssetNodeOptions } from './AssetNodeBase'

/** The site's `::asset{}` node: the shared schema and serialization, rendered by React. */
export const AssetNode = AssetNodeBase.extend({
  addNodeView() {
    return ReactNodeViewRenderer(AssetNodeView)
  },
})

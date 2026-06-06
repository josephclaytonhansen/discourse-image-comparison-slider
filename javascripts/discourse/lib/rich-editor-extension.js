import { serializeAttributes } from "discourse/lib/wrap-utils";
import ImageCompareNodeView from "../components/image-compare-node-view";
import { legacyOrientation } from "./image-compare/utils";
import {
  changedDescendants,
  toCamelCase,
  toDataAttrs,
} from "./rich-editor-utils";

const extension = {
  name: "image-compare",

  nodeSpec: {
    image_compare: {
      content: "block+",
      group: "block",
      selectable: true,
      draggable: true,
      createGapCursor: true,
      attrs: {
        data: { default: {} },
        mode: { default: null },
      },
      parseDOM: [
        {
          tag: "div[data-wrap=image-compare]",
          getAttrs: (dom) => ({ data: { ...dom.dataset } }),
        },
        // Legacy format
        {
          tag: "div[data-image-comparison-slider]",
          getAttrs: (dom) => {
            const data = { wrap: "image-compare" };
            const orientation = legacyOrientation({
              vertical: dom.hasAttribute("data-direction-vertical"),
              horizontal: dom.hasAttribute("data-direction-horizontal"),
            });
            if (orientation) {
              data.orientation = orientation;
            }
            return { data };
          },
        },
      ],
      toDOM(node) {
        return [
          "div",
          {
            class: "d-wrap",
            "data-wrap": "image-compare",
            ...toDataAttrs(node.attrs.data),
          },
          0,
        ];
      },
    },
  },

  nodeViews: {
    image_compare: {
      component: ImageCompareNodeView,
      hasContent: true,
    },
  },

  commands: ({ schema, pmState: { NodeSelection } }) => ({
    insertImageCompare() {
      return (state, dispatch) => {
        const node = schema.nodes.image_compare.createAndFill({
          data: { wrap: "image-compare" },
        });
        if (!node) {
          return false;
        }

        const tr = state.tr.replaceSelectionWith(node);

        for (let pos = tr.selection.from - 1; pos >= 0; pos--) {
          if (tr.doc.nodeAt(pos)?.type.name === "image_compare") {
            tr.setSelection(NodeSelection.create(tr.doc, pos));
            break;
          }
        }

        tr.scrollIntoView();
        dispatch?.(tr);
        return true;
      };
    },
  }),

  parse: {
    wrap_open(state, token) {
      if (token.attrGet("data-wrap") === "image-compare") {
        const attrs = {};

        for (const [key, value] of token.attrs) {
          if (key.startsWith("data-")) {
            attrs[toCamelCase(key.slice(5))] = value;
          }
        }

        state.openNode(state.schema.nodes.image_compare, { data: attrs });
        return true;
      }
    },

    wrap_close(state) {
      if (state.top().type.name === "image_compare") {
        state.closeNode();
        return true;
      }
    },

    // Legacy format
    html_block(state, token) {
      const content = token.content;

      if (/<div[^>]*\bdata-image-comparison-slider\b/.test(content)) {
        const data = { wrap: "image-compare" };
        const orientation = legacyOrientation({
          vertical: /\bdata-direction-vertical\b/.test(content),
          horizontal: /\bdata-direction-horizontal\b/.test(content),
        });
        if (orientation) {
          data.orientation = orientation;
        }
        state.openNode(state.schema.nodes.image_compare, { data });
        return true;
      }

      if (
        /^\s*<\/div>/.test(content) &&
        state.top().type.name === "image_compare"
      ) {
        state.closeNode();
        return true;
      }
    },
  },

  serializeNode: {
    image_compare(state, node) {
      const attrs = serializeAttributes(
        Object.fromEntries(
          Object.entries(node.attrs.data)
            .filter(([, value]) => value != null && String(value).trim() !== "")
            .map(([key, value]) => {
              if (key === "wrap") {
                return [key, value];
              }
              return [toCamelCase(key), `"${value}"`];
            })
        )
      );

      state.write(`[wrap${attrs}]\n`);
      const startPos = state.out.length;
      state.renderContent(node);
      const endPos = state.out.length;

      // Post-process: add newlines before images (except first)
      const content = state.out.substring(startPos, endPos);
      const withNewlines = content.replace(
        /(\]\(upload:\/\/[^)]+\))!\n*/g,
        "$1\n!"
      );
      state.out =
        state.out.substring(0, startPos) +
        withNewlines +
        state.out.substring(endPos);
      state.write("[/wrap]\n\n");
    },
  },

  plugins({
    pmState: { Plugin, NodeSelection, TextSelection, PluginKey },
    pmModel: { Fragment },
    pmView: { Decoration, DecorationSet },
  }) {
    const cursorKey = new PluginKey("imageCompareCursor");

    const CURSOR_IDLE = {
      targetPos: null,
      side: null,
      mode: null,
    };

    const imageComparePlugin = new Plugin({
      key: new PluginKey("image-compare"),

      // Normalizes to: one paragraph, only image nodes, max 2 images
      appendTransaction(transactions, oldState, newState) {
        if (
          transactions.some((tr) => tr.getMeta("imageCompareNormalization")) ||
          !transactions.some((tr) => tr.docChanged)
        ) {
          return null;
        }

        let tr = null;
        const nodesToNormalize = new Set();

        changedDescendants(oldState.doc, newState.doc, (node, pos) => {
          if (node.type.name === "image_compare") {
            nodesToNormalize.add(pos);
          }

          const $pos = newState.doc.resolve(pos);
          for (let d = $pos.depth; d > 0; d--) {
            if ($pos.node(d).type.name === "image_compare") {
              nodesToNormalize.add($pos.before(d));
              break;
            }
          }
        });

        const sortedPositions = Array.from(nodesToNormalize).sort(
          (a, b) => b - a
        );

        sortedPositions.forEach((pos) => {
          const mappedPos = tr ? tr.mapping.map(pos) : pos;
          const doc = tr ? tr.doc : newState.doc;

          const node = doc.nodeAt(mappedPos);
          if (!node || node.type.name !== "image_compare") {
            return;
          }

          const images = [];

          node.forEach((child) => {
            child.content?.forEach((inlineNode) => {
              if (inlineNode.type.name === "image") {
                // Max 2 images for comparison
                if (images.length < 2) {
                  images.push(inlineNode);
                }
              }
            });
          });

          const needsNormalization = (() => {
            if (node.childCount !== 1) {
              return true;
            }

            const paragraph = node.firstChild;
            if (paragraph.type.name !== "paragraph") {
              return true;
            }

            if (paragraph.childCount !== images.length) {
              return true;
            }

            let mismatch = false;
            paragraph.content.forEach((child, _, idx) => {
              if (child.type.name !== "image" || child !== images[idx]) {
                mismatch = true;
              }
            });

            return mismatch;
          })();

          if (!needsNormalization) {
            return;
          }

          const newNode = node.type.create(
            node.attrs,
            newState.schema.nodes.paragraph.create(
              null,
              Fragment.fromArray(images)
            )
          );

          if (!tr) {
            tr = newState.tr;
          }

          tr.replaceWith(mappedPos, mappedPos + node.nodeSize, newNode);

          const updatedNode = tr.doc.nodeAt(mappedPos);
          if (updatedNode?.attrs.mode === "edit") {
            tr.setSelection(
              TextSelection.create(
                tr.doc,
                mappedPos + 2 + updatedNode.firstChild.content.size
              )
            );
          }
        });

        if (tr) {
          tr.setMeta("addToHistory", false);
          tr.setMeta("imageCompareNormalization", true);
        }

        return tr;
      },

      props: {
        handleClickOn(view, _pos, node, nodePos) {
          if (
            node?.type.name === "image_compare" &&
            node.attrs.mode !== "edit"
          ) {
            const tr = view.state.tr.setSelection(
              NodeSelection.create(view.state.doc, nodePos)
            );
            view.dispatch(tr);
            return true;
          }
        },
      },

      view(editorView) {
        // For use in nodeview component, since we can't use import
        editorView._imageComparePM = {
          NodeSelection,
          TextSelection,
        };

        return {
          // In edit mode, the image_compare node is already selected and hidden.
          // This is a helper to toggle "has-selection" class on the node
          // so we can outline the node manually.
          update(view, prevState) {
            if (view.state.selection.eq(prevState.selection)) {
              return;
            }

            const { from, to } = view.state.selection;

            view.state.doc.descendants((node, pos) => {
              if (node.type.name !== "image_compare") {
                return;
              }

              const nodeEnd = pos + node.nodeSize;
              const isInside =
                (from >= pos && from < nodeEnd) ||
                (to > pos && to <= nodeEnd) ||
                (from < pos && to > nodeEnd);

              const nodeDOM = view.nodeDOM(pos);
              if (nodeDOM) {
                nodeDOM.classList.toggle("has-selection", isInside);
              }

              return false;
            });
          },
        };
      },
    });

    // Replaces the default cursor with a decoration
    // for better visibility and positioning.
    const cursorPlugin = new Plugin({
      key: cursorKey,

      state: {
        init() {
          return CURSOR_IDLE;
        },
        apply(_tr, _prev, _oldState, newState) {
          const { selection } = newState;

          if (!(selection instanceof TextSelection) || !selection.empty) {
            return CURSOR_IDLE;
          }

          const $pos = selection.$from;

          for (let depth = $pos.depth; depth >= 0; depth--) {
            const node = $pos.node(depth);

            if (node.type.name === "image_compare") {
              const parent = $pos.parent;
              const index = $pos.index();

              const hasImages = parent.content.content.some(
                (child) => child.type.name === "image"
              );

              if (!hasImages) {
                return { cursorPos: $pos.pos, mode: "empty" };
              }

              if (index > 0) {
                return {
                  targetPos: $pos.posAtIndex(index - 1, $pos.depth),
                  side: "after",
                  mode: "node",
                };
              }

              if (index < parent.childCount) {
                return {
                  targetPos: $pos.posAtIndex(index, $pos.depth),
                  side: "before",
                  mode: "node",
                };
              }

              return CURSOR_IDLE;
            }
          }

          return CURSOR_IDLE;
        },
      },

      props: {
        decorations(state) {
          const caret = cursorKey.getState(state);

          if (!caret?.mode) {
            return null;
          }

          if (caret.mode === "empty") {
            return DecorationSet.create(state.doc, [
              Decoration.widget(
                caret.cursorPos,
                () => {
                  const element = document.createElement("span");
                  element.className = "image-compare-caret-widget";
                  return element;
                },
                { side: -1 }
              ),
            ]);
          }

          if (caret.targetPos == null || !caret.side) {
            return null;
          }

          const node = state.doc.nodeAt(caret.targetPos);
          if (!node) {
            return null;
          }

          return DecorationSet.create(state.doc, [
            Decoration.node(caret.targetPos, caret.targetPos + node.nodeSize, {
              class:
                caret.side === "after" ? "has-caret-after" : "has-caret-before",
            }),
          ]);
        },
      },
    });

    return [imageComparePlugin, cursorPlugin];
  },
};

export default extension;

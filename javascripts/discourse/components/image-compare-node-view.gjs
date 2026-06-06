import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import { composerI18n as i18nKey } from "../lib/image-compare/i18n";
import { MENU_PADDING, settingsMenuOptions } from "../lib/image-compare/menu";
import ImageCompareUiState from "../lib/image-compare/ui-state";
import { normalizeConfig } from "../lib/image-compare/utils";
import ImageCompare from "./image-compare";
import ImageCompareToolbar from "./image-compare-toolbar";

let menuIndex = 0;

class LeftToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    if (opts.editMode) {
      this.addButton({
        id: "image-compare-validate",
        icon: "circle-check",
        title: themePrefix("image_compare.composer.toolbar.validate"),
        action: opts.toggleEditMode,
        get disabled() {
          return !opts.hasImages();
        },
        tabindex: 0,
      });
    } else {
      this.addButton({
        id: "image-compare-edit",
        icon: "images",
        title: themePrefix("image_compare.composer.toolbar.edit"),
        action: opts.toggleEditMode,
        tabindex: 0,
      });
    }
  }
}

class RightToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "image-compare-delete",
      icon: "trash-can",
      title: themePrefix("image_compare.composer.toolbar.delete"),
      action: opts.deleteNode,
      tabindex: 0,
    });
  }
}

export default class ImageCompareNodeView extends Component {
  @service menu;
  @service previewState;

  @tracked isEditMode = false;
  @tracked isSelected = false;

  toolbar = { left: null, right: null };
  menuInstances = { left: null, right: null };
  settingsMenu = null;
  uiState = new ImageCompareUiState();

  constructor() {
    super(...arguments);

    menuIndex++;
    this.menuId = menuIndex;
    this.args.onSetup?.(this);

    this.contentDOM.classList.add("composer-ic-node__content");

    if (!this.hasImages) {
      this.isEditMode = true;
      this.args.dom.classList.add("edit");

      next(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        const { view, getPos, node } = this.args;
        const pos = getPos();
        if (typeof pos !== "number") {
          return;
        }

        const tr = view.state.tr.setNodeMarkup(pos, null, {
          ...node.attrs,
          mode: "edit",
        });
        view.dispatch(tr);
        this.showToolbar();
      });
    }
  }

  willDestroy() {
    this.closeMenus();
    super.willDestroy(...arguments);
  }

  get contentDOM() {
    return this.args.dom.firstElementChild;
  }

  @cached
  get config() {
    return normalizeConfig(this.args.node.attrs.data);
  }

  @cached
  get imageNodes() {
    return (
      this.args.node.firstChild?.content.content.filter(
        (child) => child.type.name === "image"
      ) ?? []
    );
  }

  get hasImages() {
    return this.imageNodes.length >= 2;
  }

  get aspectMismatch() {
    const ratio = (node) => {
      const w = parseFloat(node?.attrs?.width);
      const h = parseFloat(node?.attrs?.height);

      return w > 0 && h > 0 ? w / h : null;
    };

    const before = ratio(this.imageNodes[0]);
    const after = ratio(this.imageNodes[1]);

    if (before === null || after === null) {
      return false;
    }

    return Math.abs(before - after) / before > 0.02;
  }

  get beforeSrc() {
    return this.imageNodes[0]?.attrs?.src ?? null;
  }

  get afterSrc() {
    return this.imageNodes[1]?.attrs?.src ?? null;
  }

  @cached
  get data() {
    return {
      ...this.config,
      images: {
        before: { previewSrc: this.beforeSrc },
        after: { previewSrc: this.afterSrc },
      },
      uiState: this.uiState,
    };
  }

  get settingsAnchor() {
    return this.args.dom.querySelector(".composer-ic-node__preview");
  }

  async showToolbar() {
    if (this.menuInstances.left) {
      return;
    }

    this.toolbar.left ??= new LeftToolbar({
      toggleEditMode: this.toggleEditMode,
      openSettings: this.openSettings,
      editMode: this.isEditMode,
      hasImages: () => this.imageNodes.length >= 2,
    });

    this.toolbar.right ??= new RightToolbar({
      deleteNode: this.deleteNode,
    });

    const extraId = this.isEditMode ? `-edit-${this.menuId}` : "";

    const leftOptions = {
      identifier: `composer-ic-toolbar--left${extraId}`,
      component: ToolbarButtons,
      placement: "top-start",
      fallbackPlacements: ["top-start"],
      padding: MENU_PADDING,
      data: this.toolbar.left,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: MENU_PADDING,
        };
      },
      limitShift: {
        offset: ({ rects, placement }) => ({
          crossAxis:
            (-rects.floating.height - MENU_PADDING) *
            (placement.includes("start") ? -1 : 1),
        }),
      },
    };

    const rightOptions = {
      ...leftOptions,
      identifier: `composer-ic-toolbar--right${extraId}`,
      data: this.toolbar.right,
      placement: "top-end",
      fallbackPlacements: ["top-end"],
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: -MENU_PADDING,
        };
      },
    };

    const left = await this.menu.newInstance(this.args.dom, leftOptions);
    const right = await this.menu.newInstance(this.args.dom, rightOptions);

    if (this.isDestroying || this.isDestroyed) {
      left.close?.();
      right.close?.();
      return;
    }

    this.menuInstances = { left, right };

    await left.show();
    await right.show();
  }

  closeMenus() {
    for (const side of Object.keys(this.menuInstances)) {
      this.menuInstances[side]?.close();
      this.menuInstances[side] = null;
      this.toolbar[side] = null;
    }
    this.closeSettingsMenu();
  }

  selectNode() {
    if (this.isEditMode) {
      return;
    }

    this.isSelected = true;
    this.args.dom.classList.add("ProseMirror-selectednode");
    this.showToolbar();

    if (!this.settingsMenu && !this.isEditMode) {
      this.openSettings();
    }
  }

  deselectNode() {
    if (this.isEditMode && this.args.dom.classList.contains("has-selection")) {
      return;
    }

    if (this.isEditMode) {
      this.isEditMode = false;
      this.args.dom.classList.remove("edit");
    }

    this.isSelected = false;
    this.args.dom.classList.remove("ProseMirror-selectednode");

    this.previewState.clearSavedDragPosition(
      `ic-settings-pos-${this.args.node.attrs.data?.wrapIndex}`
    );

    this.closeMenus();
  }

  stopEvent(event) {
    const { type, target } = event;

    if (this.isEditMode && this.contentDOM.contains(target)) {
      if (type === "mousedown" && target.tagName !== "IMG") {
        this.placeCursorAtCoords(event);
        return true;
      }
      return false;
    }

    return false;
  }

  placeCursorAtCoords(event) {
    const { view, getPos, node } = this.args;
    const { TextSelection } = view._imageComparePM;
    const nodePos = getPos();

    const coords = view.posAtCoords({
      left: event.clientX,
      top: event.clientY,
    });

    const targetPos =
      coords?.pos > nodePos && coords.pos < nodePos + node.nodeSize
        ? coords.pos
        : nodePos + 2 + node.firstChild.content.size;

    view.dispatch(
      view.state.tr.setSelection(
        TextSelection.create(view.state.doc, targetPos)
      )
    );
    view.focus();
  }

  @action
  async toggleEditMode() {
    await this.closeMenus();

    this.isEditMode = !this.isEditMode;
    this.showToolbar();

    const { view, dom, getPos, node } = this.args;

    this.previewState.clearSavedDragPosition(
      `ic-settings-pos-${node.attrs.data.wrapIndex}`
    );

    if (this.isEditMode) {
      dom.classList.add("edit");

      const pos = getPos();
      const { TextSelection } = view._imageComparePM;
      const tr = view.state.tr.setNodeMarkup(pos, null, {
        ...node.attrs,
        mode: "edit",
      });
      const cursorPos = pos + 2 + node.firstChild.content.size;
      tr.setSelection(TextSelection.create(tr.doc, cursorPos));
      view.dispatch(tr);

      next(() => {
        dom.scrollIntoView({ block: "center" });
      });
    } else {
      dom.classList.remove("edit");

      const pos = getPos();
      const tr = view.state.tr.setNodeMarkup(pos, null, {
        ...node.attrs,
        mode: "view",
      });
      const { NodeSelection } = view._imageComparePM;
      tr.setSelection(NodeSelection.create(tr.doc, pos));
      view.dispatch(tr);
      view.focus();
    }
  }

  @action
  swapImages() {
    const { view, getPos, node } = this.args;
    const images = this.imageNodes;

    if (images.length < 2) {
      return;
    }

    const paragraph = node.firstChild;
    const pos = getPos();

    const imagePositions = [];
    let offset = 0;
    paragraph.content.forEach((child) => {
      if (child.type.name === "image") {
        imagePositions.push({
          node: child,
          pos: pos + 2 + offset,
          size: child.nodeSize,
        });
      }
      offset += child.nodeSize;
    });

    if (imagePositions.length < 2) {
      return;
    }

    const [first, second] = imagePositions;
    const tr = view.state.tr;

    tr.delete(second.pos, second.pos + second.size);
    tr.delete(first.pos, first.pos + first.size);

    tr.insert(first.pos, second.node);
    tr.insert(first.pos + second.size, first.node);

    view.dispatch(tr);
  }

  @action
  async openSettings() {
    if (this.settingsMenu) {
      this.closeSettingsMenu();
      return;
    }

    const instance = await this.menu.newInstance(
      this.settingsAnchor,
      settingsMenuOptions({
        identifier: `composer-ic-settings-${this.menuId}`,
        component: ImageCompareToolbar,
        portalOutletElement: this.args.dom,
        data: {
          getConfig: () => this.config,
          updateSetting: this.updateSetting,
          uiState: this.uiState,
        },
      })
    );

    if (this.isDestroying || this.isDestroyed) {
      this.menu.close(instance);
      return;
    }

    this.settingsMenu = instance;
    await this.settingsMenu.show();
  }

  @action
  closeSettingsMenu() {
    if (this.settingsMenu) {
      this.menu.close(this.settingsMenu);
      this.settingsMenu = null;
    }
  }

  @action
  updateSetting(key, value) {
    const { view, getPos } = this.args;
    const pos = getPos();
    if (typeof pos !== "number") {
      return;
    }

    const currentNode = view.state.doc.nodeAt(pos);
    if (!currentNode || currentNode.attrs.data?.[key] === value) {
      return;
    }

    const { NodeSelection } = view._imageComparePM;
    const tr = view.state.tr.setNodeMarkup(pos, null, {
      ...currentNode.attrs,
      data: { ...currentNode.attrs.data, [key]: value },
    });
    tr.setSelection(NodeSelection.create(tr.doc, pos));
    view.dispatch(tr);
  }

  @action
  deleteNode() {
    const { view, getPos } = this.args;
    const pos = getPos();
    const tr = view.state.tr.delete(pos, pos + this.args.node.nodeSize);
    view.dispatch(tr);
    view.focus();
  }

  <template>
    {{#if this.isEditMode}}
      <div class="composer-ic-node__edit" contenteditable="false">
        <div class="composer-ic-node__slots">
          <div class="composer-ic-node__slot">
            <span class="composer-ic-node__slot-label">{{i18nKey
                "edit.before_slot"
              }}</span>
          </div>
          <DButton
            @icon="arrow-right-arrow-left"
            @action={{this.swapImages}}
            @translatedTitle={{i18nKey "edit.swap"}}
            @disabled={{not this.hasImages}}
            class="composer-ic-node__swap btn-flat btn-small"
          />
          <div class="composer-ic-node__slot">
            <span class="composer-ic-node__slot-label">{{i18nKey
                "edit.after_slot"
              }}</span>
          </div>
        </div>
      </div>
    {{else if this.hasImages}}

      <div class="composer-ic-node__preview" contenteditable="false">
        <ImageCompare @data={{this.data}} />
      </div>
      {{#if this.aspectMismatch}}
        <div class="composer-ic-node__notice" contenteditable="false">
          {{icon "circle-info"}}
          <span>{{i18nKey "size_mismatch"}}</span>
        </div>
      {{/if}}
    {{/if}}
  </template>
}

import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import dragPanel from "../modifiers/drag-panel";
import CaptionTool from "./image-compare-toolbar/caption";
import ColorTool from "./image-compare-toolbar/color";
import LabelsTool from "./image-compare-toolbar/labels";
import PositionTool from "./image-compare-toolbar/position";
import StyleTool from "./image-compare-toolbar/style";

const i18nKey = (key) =>
  i18n(themePrefix(`image_compare.composer.settings.${key}`));

export const TOOLBAR_SURFACE_SELECTOR = `
  .ic-toolbar,
  .ic-toolbar__submenu,
  [data-identifier^='composer-ic-settings'],
  [data-identifier^='preview-ic-settings']
`;

const Grip = <template>
  <div
    class="ic-toolbar__grip"
    aria-hidden="true"
    {{dragPanel @selector boundarySelector=".d-editor" onDragEnd=@onDragEnd}}
  >
    {{icon "grip-vertical"}}
  </div>
</template>;

export default class ImageCompareToolbar extends Component {
  @service previewState;

  menuApis = new Set();

  restoreDragPosition = modifier((element) => {
    const id = this.dragStorageKey;
    const panel = element.closest(this.dragSelector);
    if (!panel) {
      return;
    }

    const saved = this.previewState.getSavedDragPosition(id);
    if (saved) {
      panel.classList.add("is-manually-positioned");
      panel.style.setProperty("--drag-tx", saved.tx);
      panel.style.setProperty("--drag-ty", saved.ty);
    } else {
      panel.classList.remove("is-manually-positioned");
      panel.style.removeProperty("--drag-tx");
      panel.style.removeProperty("--drag-ty");
    }
  });

  closeMenuOnOutsideClick = modifier((element) => {
    const handler = (event) => {
      if (!document.contains(event.target)) {
        return;
      }

      if (element.contains(event.target)) {
        return;
      }

      const active = this.activeMenuApi;

      if (active?.content?.contains(event.target)) {
        return;
      }

      if (active) {
        active.close({ focusTrigger: false });
      }

      this.isCollapsedOpen = false;
      this.openToolKey = null;
    };

    document.addEventListener("click", handler);

    return () => {
      document.removeEventListener("click", handler);
    };
  });

  resolveIcon = (tool) => {
    return tool.iconFor ? tool.iconFor(this.config) : tool.icon;
  };

  isToolActive = (tool) => {
    return tool.activeFor?.(this.config) ?? false;
  };

  willDestroy() {
    super.willDestroy(...arguments);
  }

  get openToolKey() {
    return this.uiState.openToolKey;
  }

  set openToolKey(value) {
    this.uiState.openToolKey = value;
  }

  get isCollapsedOpen() {
    return this.uiState.isCollapsedOpen;
  }

  set isCollapsedOpen(value) {
    this.uiState.isCollapsedOpen = value;
  }

  get dragSelector() {
    const id = this.args.data.menuIdentifier ?? "composer-ic-settings";
    return `[data-identifier^='${id}']`;
  }

  get dragStorageKey() {
    return `ic-settings-pos-${this.args.data.wrapIndex}`;
  }

  get activeMenuApi() {
    return [...this.menuApis].find((api) => {
      try {
        return api.expanded;
      } catch {
        return false;
      }
    });
  }

  get config() {
    return this.args.data.getConfig();
  }

  get uiState() {
    return this.args.data.uiState;
  }

  get isPreviewMode() {
    return this.args.data.isPreview;
  }

  get isCollapsed() {
    return this.uiState.toolbarCollapsed;
  }

  @cached
  get tools() {
    return [
      {
        key: "orientation",
        titleKey: "orientation",
        toggle: true,
        action: this.toggleOrientation,
        icon: "ict-orientation-dot",
        activeFor: (c) => c.orientation === "vertical",
      },
      {
        key: "position",
        titleKey: "position",
        component: PositionTool,
        iconFor: (c) =>
          c.orientation === "vertical"
            ? "ict-position-vertical"
            : "ict-position-horizontal",
      },
      {
        key: "style",
        titleKey: "style",
        icon: "ict-style",
        component: StyleTool,
      },
      {
        key: "color",
        titleKey: "color",
        icon: "ict-color",
        component: ColorTool,
      },
      {
        key: "labels",
        titleKey: "label",
        icon: "ict-labels",
        component: LabelsTool,
      },
      {
        key: "caption",
        titleKey: "caption",
        icon: "ict-caption",
        component: CaptionTool,
      },
    ];
  }

  @cached
  get openToolIcon() {
    const tool = this.tools.find((t) => t.key === this.openToolKey);
    return tool ? this.resolveIcon(tool) : null;
  }

  @cached
  get toolData() {
    return {
      getConfig: () => this.config,
      updateSetting: this.updateSetting,
      isPreviewMode: this.isPreviewMode,
    };
  }

  @action
  saveDragPosition() {
    const id = this.dragStorageKey;
    const panel = document.querySelector(this.dragSelector);

    if (!panel?.classList.contains("is-manually-positioned")) {
      return;
    }
    const tx = panel.style.getPropertyValue("--drag-tx");
    const ty = panel.style.getPropertyValue("--drag-ty");

    if (tx || ty) {
      this.previewState.saveDragPosition(id, { tx, ty });
    }
  }

  @action
  updateSetting(key, value) {
    const active = this.activeMenuApi;
    this.previewState.setActiveSubmenuId(active?.options?.identifier);
    this.args.data.updateSetting(key, value);
  }

  @action
  toggleOrientation() {
    if (!this.isCollapsed) {
      this.activeMenuApi?.close({ focusTrigger: false });
    }

    this.updateSetting(
      "orientation",
      this.config.orientation === "vertical" ? "horizontal" : "vertical"
    );
  }

  @action
  toggleCollapsedOpen() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.openToolKey) {
      this.openToolKey = null;
      const settingsApi = [...this.menuApis].find(
        (a) => a.options?.identifier === "ic-toolbar-settings-menu"
      );
      next(() => settingsApi?.show?.());
    } else {
      this.isCollapsedOpen = !this.isCollapsedOpen;
    }
  }

  @action
  openCollapsedTool(key) {
    this.openToolKey = this.openToolKey === key ? null : key;
  }

  @action
  registerMenuApi(api) {
    this.menuApis.add(api);

    // Re-open the submenu that was active before a preview re-render
    const pendingSubmenuId = this.previewState.activeSubmenuId;
    if (
      this.isPreviewMode &&
      pendingSubmenuId &&
      api.options?.identifier === pendingSubmenuId
    ) {
      this.previewState.setActiveSubmenuId(null);
      api.show?.();
    }
  }

  @action
  preventButtonFocus(event) {
    event.preventDefault();
  }

  @action
  async closeActiveMenu() {
    const active = this.activeMenuApi;
    if (active) {
      await active.close({ focusTrigger: false });
    }
  }

  <template>
    <div
      class={{concatClass
        "ic-toolbar"
        (if this.isCollapsed "ic-toolbar--collapsed")
        (if this.isCollapsedOpen "ic-toolbar--open")
        (if this.openToolKey "ic-toolbar--has-open-tool")
      }}
      {{this.closeMenuOnOutsideClick}}
      {{this.restoreDragPosition}}
    >
      {{#if this.isCollapsed}}
        <div class="ic-toolbar__pill ic-toolbar__pill--settings">
          {{! template-lint-disable no-pointer-down-event-binding }}
          <DMenu
            @placement="top"
            @identifier="ic-toolbar-settings-menu"
            @inline={{false}}
            @beforeTrigger={{this.closeActiveMenu}}
            @onRegisterApi={{this.registerMenuApi}}
            @contentClass="ic-toolbar__submenu"
            @icon={{if this.openToolKey this.openToolIcon "gear"}}
            @onClose={{this.toggleCollapsedOpen}}
            @offset={{20}}
            title={{i18nKey "settings"}}
            class={{concatClass
              "btn-transparent ic-toolbar__button"
              (if this.openToolKey "is-active")
            }}
            {{on "mousedown" this.preventButtonFocus}}
          >
            <:content>
              {{#if this.openToolKey}}
                <div class="ic-toolbar__submenu ic-toolbar__submenu--collapsed">
                  {{#each this.tools as |tool|}}
                    {{#if (eq this.openToolKey tool.key)}}
                      <tool.component @data={{this.toolData}} />
                    {{/if}}
                  {{/each}}
                </div>
              {{else}}
                <div class="ic-toolbar__pill ic-toolbar__pill--tools">
                  {{#each this.tools as |tool|}}
                    <DButton
                      class={{concatClass
                        "btn-transparent ic-toolbar__button"
                        (if (this.isToolActive tool) "is-active")
                        (if
                          (eq tool.key "orientation")
                          "ic-toolbar__button--orientation"
                        )
                      }}
                      title={{i18nKey tool.titleKey}}
                      @icon={{this.resolveIcon tool}}
                      @action={{if
                        tool.toggle
                        tool.action
                        (fn this.openCollapsedTool tool.key)
                      }}
                      @preventFocus={{true}}
                    />
                  {{/each}}
                </div>
              {{/if}}
            </:content>
          </DMenu>

          <Grip
            @selector={{this.dragSelector}}
            @onDragEnd={{this.saveDragPosition}}
          />
        </div>
      {{else}}
        <div class="ic-toolbar__pill ic-toolbar__pill--tools">
          <Grip
            @selector={{this.dragSelector}}
            @onDragEnd={{this.saveDragPosition}}
          />

          {{#each this.tools as |tool|}}
            <div class="ic-toolbar__item">
              {{#if tool.toggle}}
                <DButton
                  class={{concatClass
                    "btn-transparent ic-toolbar__button"
                    (if (this.isToolActive tool) "is-active")
                    (if
                      (eq tool.key "orientation")
                      "ic-toolbar__button--orientation"
                    )
                  }}
                  title={{i18nKey tool.titleKey}}
                  @icon={{this.resolveIcon tool}}
                  @action={{tool.action}}
                  @preventFocus={{true}}
                />
              {{else}}
                {{! template-lint-disable no-pointer-down-event-binding }}
                <DMenu
                  @placement="bottom"
                  @identifier="ic-toolbar-{{tool.key}}-menu"
                  @inline={{false}}
                  @beforeTrigger={{this.closeActiveMenu}}
                  @onRegisterApi={{this.registerMenuApi}}
                  @contentClass="ic-toolbar__submenu"
                  @icon={{this.resolveIcon tool}}
                  @offset={{20}}
                  title={{i18nKey tool.titleKey}}
                  class="btn-transparent ic-toolbar__button"
                  {{on "mousedown" this.preventButtonFocus}}
                >
                  <:content>
                    <tool.component @data={{this.toolData}} />
                  </:content>
                </DMenu>
              {{/if}}
            </div>
          {{/each}}

          <Grip
            @selector={{this.dragSelector}}
            @onDragEnd={{this.saveDragPosition}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}

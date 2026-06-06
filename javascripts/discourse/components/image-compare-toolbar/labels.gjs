import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import { settingsI18n as i18nKey } from "../../lib/image-compare/i18n";
import ToolBase from "./tool-base";

const LABEL_POSITIONS = [
  { value: "start", icon: "align-left", titleKey: "label_position_start" },
  { value: "center", icon: "align-center", titleKey: "label_position_center" },
  { value: "end", icon: "align-right", titleKey: "label_position_end" },
];

export default class LabelsTool extends ToolBase {
  @tracked pending = {};

  get showLabels() {
    return this.config.showLabels !== false;
  }

  get displayBefore() {
    return this.pending.beforeLabel ?? this.config.beforeLabel;
  }

  get displayAfter() {
    return this.pending.afterLabel ?? this.config.afterLabel;
  }

  @action
  toggleShowLabels() {
    this.args.data.updateSetting("showLabels", !this.showLabels);
  }

  @action
  onInput(key, event) {
    if (this.args.data.isPreviewMode) {
      this.pending = { ...this.pending, [key]: event.target.value };
      return;
    }

    this.args.data.updateSetting(key, event.target.value);
  }

  @action
  commit(key, event) {
    const value = event.target.value;

    if (value !== this.config[key]) {
      this.args.data.updateSetting(key, value);
    }

    this.pending = { ...this.pending, [key]: null };
  }

  <template>
    <div class="ic-toolbar__menu ic-toolbar__menu--column" ...attributes>
      <div class="ic-toolbar__menu-row">
        <span class="ic-toolbar__menu-label">{{i18nKey "show_labels"}}</span>
        <DToggleSwitch
          @state={{this.showLabels}}
          aria-label={{i18nKey "show_labels"}}
          {{on "click" this.toggleShowLabels}}
        />
      </div>
      <div class="ic-toolbar__menu-row">
        {{#each LABEL_POSITIONS as |pos|}}
          <DButton
            @icon={{pos.icon}}
            @action={{fn @data.updateSetting "labelPosition" pos.value}}
            @preventFocus={{true}}
            class={{concatClass
              "btn-flat ic-toolbar__menu-button"
              (if (eq this.config.labelPosition pos.value) "is-active")
            }}
            title={{i18nKey pos.titleKey}}
          />
        {{/each}}
      </div>
      <div class="ic-toolbar__menu-row">
        <input
          type="text"
          class="ic-toolbar__input ic-toolbar__input--label"
          aria-label={{i18nKey "before_label_placeholder"}}
          placeholder={{i18nKey "before_label_placeholder"}}
          value={{this.displayBefore}}
          {{on "input" (fn this.onInput "beforeLabel")}}
          {{on "blur" (fn this.commit "beforeLabel")}}
          {{on "keydown" this.onKeydown}}
        />
      </div>
      <div class="ic-toolbar__menu-row">
        <input
          type="text"
          class="ic-toolbar__input ic-toolbar__input--label"
          aria-label={{i18nKey "after_label_placeholder"}}
          placeholder={{i18nKey "after_label_placeholder"}}
          value={{this.displayAfter}}
          {{on "input" (fn this.onInput "afterLabel")}}
          {{on "blur" (fn this.commit "afterLabel")}}
          {{on "keydown" this.onKeydown}}
        />
      </div>
    </div>
  </template>
}

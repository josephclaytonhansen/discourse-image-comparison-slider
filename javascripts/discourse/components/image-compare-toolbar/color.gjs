import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { settingsI18n as i18nKey } from "../../lib/image-compare/i18n";
import { isValidHandleColor } from "../../lib/image-compare/utils";
import ToolBase from "./tool-base";

export default class ColorTool extends ToolBase {
  @tracked pending = null;
  animationFrame = null;

  willDestroy() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }

    super.willDestroy(...arguments);
  }

  get displayColor() {
    const color = this.config.handleColor || settings.default_handle_color;
    if (color) {
      return color;
    }

    const secondary = getComputedStyle(document.documentElement)
      .getPropertyValue("--secondary")
      .trim();
    return secondary;
  }

  @action
  update(value) {
    if (value === this.config.handleColor || value === this.pending) {
      return;
    }

    this.pending = value;

    if (this.args.data.isPreviewMode || this.animationFrame) {
      return;
    }

    this.animationFrame = requestAnimationFrame(() => {
      this.animationFrame = null;
      this.flush();
    });
  }

  @action
  flush(value = this.pending) {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }

    if (value == null) {
      return;
    }

    this.pending = null;
    this.args.data.updateSetting("handleColor", value);
  }

  @action
  commitText(event) {
    const value = event.target.value;

    if (!isValidHandleColor(value)) {
      event.target.value = this.config.handleColor;
      return;
    }

    if (value !== this.config.handleColor) {
      this.args.data.updateSetting("handleColor", value);
    }

    this.pending = null;
  }

  @action
  reset() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }

    this.pending = null;
    this.args.data.updateSetting("handleColor", "");
  }

  <template>
    <div class="ic-toolbar__menu">
      <input
        type="color"
        value={{this.displayColor}}
        class="ic-toolbar__color-input"
        aria-label={{i18nKey "color"}}
        {{on "input" (withEventValue this.update)}}
        {{on "change" (withEventValue this.flush)}}
      />
      <input
        type="text"
        class="ic-toolbar__input ic-toolbar__input--code"
        placeholder={{this.displayColor}}
        aria-label={{i18nKey "color"}}
        value={{this.config.handleColor}}
        {{on "blur" this.commitText}}
        {{on "keydown" this.onKeydown}}
      />
      {{#if this.config.handleColor}}
        <DButton
          class="btn-transparent ic-toolbar__button ic-toolbar__button--reset-color"
          @icon="clock-rotate-left"
          @action={{this.reset}}
          @preventFocus={{true}}
          title={{i18nKey "color_reset"}}
        />
      {{/if}}
    </div>
  </template>
}

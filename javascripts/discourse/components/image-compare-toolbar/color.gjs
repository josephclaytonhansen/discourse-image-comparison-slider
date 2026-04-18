import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { isValidHandleColor } from "../../lib/image-compare/utils";

export default class ColorTool extends Component {
  @tracked pending = null;
  animationFrame = null;

  willDestroy() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }

    super.willDestroy(...arguments);
  }

  get config() {
    return this.args.data.getConfig();
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
  onKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    }
  }

  <template>
    <div class="ic-toolbar__menu">
      <input
        type="color"
        value={{this.config.handleColor}}
        class="ic-toolbar__color-input"
        {{on "input" (withEventValue this.update)}}
        {{on "change" (withEventValue this.flush)}}
      />
      <input
        type="text"
        class="ic-toolbar__input ic-toolbar__input--code"
        placeholder="#ffffff"
        value={{this.config.handleColor}}
        {{on "blur" this.commitText}}
        {{on "keydown" this.onKeydown}}
      />
    </div>
  </template>
}

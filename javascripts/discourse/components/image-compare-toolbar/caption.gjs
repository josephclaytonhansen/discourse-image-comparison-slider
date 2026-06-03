import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { settingsI18n as i18nKey } from "../../lib/image-compare/i18n";
import ToolBase from "./tool-base";

export default class CaptionTool extends ToolBase {
  @tracked pending = null;

  get display() {
    return this.pending ?? this.config.caption;
  }

  @action
  onInput(event) {
    const value = event.target.value;
    if (this.args.data.isPreviewMode) {
      this.pending = value;
      return;
    }
    this.args.data.updateSetting("caption", value);
  }

  @action
  commit(event) {
    const value = event.target.value;

    if (value !== this.config.caption) {
      this.args.data.updateSetting("caption", value);
    }

    this.pending = null;
  }

  @action
  clear() {
    this.pending = null;
    this.args.data.updateSetting("caption", "");
  }

  <template>
    <div class="ic-toolbar__menu">
      <div class="ic-toolbar__input-wrapper">
        <input
          type="text"
          class="ic-toolbar__input ic-toolbar__input--caption"
          placeholder={{i18nKey "caption_placeholder"}}
          value={{this.display}}
          {{on "input" this.onInput}}
          {{on "blur" this.commit}}
          {{on "keydown" this.onKeydown}}
        />
        {{#if this.display}}
          <DButton
            class="btn-transparent ic-toolbar__input-clear"
            @icon="xmark"
            @action={{this.clear}}
            @preventFocus={{true}}
            title={{i18nKey "clear"}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}

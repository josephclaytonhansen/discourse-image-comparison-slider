import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { eq } from "discourse/truth-helpers";

export default class PositionTool extends Component {
  @tracked pending = null;

  get config() {
    return this.args.data.getConfig();
  }

  get display() {
    return this.pending ?? this.config.position;
  }

  @action
  onInput(value) {
    if (this.args.data.isPreviewMode) {
      this.pending = Number(value);
      return;
    }

    this.args.data.updateSetting("position", value);
  }

  @action
  commit(value) {
    this.pending = null;
    this.args.data.updateSetting("position", value);
  }

  <template>
    <div class="ic-toolbar__menu">
      <input
        type="range"
        class="ic-toolbar__slider"
        value={{this.display}}
        min="0"
        max="100"
        {{on "input" (withEventValue this.onInput)}}
        {{on "change" (withEventValue this.commit)}}
      />
      <DButton
        @action={{fn @data.updateSetting "position" 50}}
        @icon="clock-rotate-left"
        @preventFocus={{true}}
        class="btn-transparent btn-small ic-toolbar__menu-button ic-toolbar__action ic-toolbar__action--revert
          {{if (eq this.display 50) 'is-hidden'}}"
      />
    </div>
  </template>
}

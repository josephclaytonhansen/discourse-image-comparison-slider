import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";
import { settingsI18n as i18nKey } from "../../lib/image-compare/i18n";
import ToolBase from "./tool-base";

const STYLES = [
  {
    value: "default",
    label: i18nKey("style_line"),
  },
  {
    value: "thin",
    label: i18nKey("style_thin"),
  },
  {
    value: "circle",
    label: i18nKey("style_circle"),
  },
  {
    value: "grabber",
    label: i18nKey("style_grabber"),
  },
];

export default class StyleTool extends ToolBase {
  <template>
    <div class="ic-toolbar__menu">
      {{#each STYLES as |style|}}
        <DButton
          @action={{fn @data.updateSetting "handleStyle" style.value}}
          class={{concatClass
            "btn-flat ic-toolbar__menu-button"
            (if (eq this.config.handleStyle style.value) "is-active")
          }}
          @translatedLabel={{style.label}}
          @preventFocus={{true}}
        />
      {{/each}}
    </div>
  </template>
}

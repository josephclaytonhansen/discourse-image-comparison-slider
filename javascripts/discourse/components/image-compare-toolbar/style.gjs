import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const i18nKey = (key) =>
  i18n(themePrefix(`image_compare.composer.settings.${key}`));

const STYLES = [
  {
    value: "default",
    label: i18nKey("style_line"),
  },
  {
    value: "circle",
    label: i18nKey("style_circle"),
  },
];

export default class StyleTool extends Component {
  get config() {
    return this.args.data.getConfig();
  }

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

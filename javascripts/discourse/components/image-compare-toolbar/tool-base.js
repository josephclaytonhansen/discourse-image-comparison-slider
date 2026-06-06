import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ToolBase extends Component {
  get config() {
    return this.args.data.getConfig();
  }

  @action
  onKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    }
  }
}

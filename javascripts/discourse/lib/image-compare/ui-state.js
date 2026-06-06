import { tracked } from "@glimmer/tracking";

export default class ImageCompareUiState {
  @tracked toolbarCollapsed = false;
  @tracked openToolKey = null;
  @tracked isCollapsedOpen = false;
}

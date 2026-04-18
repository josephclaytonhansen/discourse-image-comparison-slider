import Service from "@ember/service";
import ImageCompareUiState from "../lib/image-compare/ui-state";

export default class PreviewState extends Service {
  selectedWrapIndex = null;
  activeSubmenuId = null;

  savedDragPositions = new Map();
  uiStates = new Map();

  stateFor(wrapIndex) {
    if (!this.uiStates.has(wrapIndex)) {
      this.uiStates.set(wrapIndex, new ImageCompareUiState());
    }

    return this.uiStates.get(wrapIndex);
  }

  setSelectedWrapIndex(value) {
    this.selectedWrapIndex = value;
  }

  setActiveSubmenuId(value) {
    this.activeSubmenuId = value;
  }

  saveDragPosition(id, value) {
    this.savedDragPositions.set(id, value);
  }

  getSavedDragPosition(id) {
    return this.savedDragPositions.get(id);
  }

  clearSavedDragPosition(id) {
    this.savedDragPositions.delete(id);
  }

  reset() {
    this.selectedWrapIndex = null;
    this.activeSubmenuId = null;
    this.savedDragPositions.clear();
    this.uiStates.clear();
  }
}

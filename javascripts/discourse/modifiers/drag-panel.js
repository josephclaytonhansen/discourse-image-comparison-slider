import { modifier } from "ember-modifier";
import { DragPanel } from "../lib/drag-panel";

export default modifier((element, [targetSelector], namedArgs) => {
  let dragPanelInstance = null;
  let hasStarted = false;

  function onStart(event) {
    if (hasStarted) {
      return;
    }

    const target = element.closest(targetSelector);
    if (!target) {
      return;
    }

    event.preventDefault();

    hasStarted = true;
    dragPanelInstance = new DragPanel(
      element,
      target,
      namedArgs?.boundarySelector
    );
    dragPanelInstance.start(event);

    document.addEventListener("mousemove", onMove, { passive: false });
    document.addEventListener("touchmove", onMove, { passive: false });
    document.addEventListener("mouseup", onEnd, { passive: false });
    document.addEventListener("touchend", onEnd, { passive: false });
    document.body.classList.add("is-dragging");
  }

  function onMove(event) {
    dragPanelInstance?.move(event);
  }

  function onEnd() {
    if (!hasStarted) {
      return;
    }
    hasStarted = false;

    dragPanelInstance?.end();
    dragPanelInstance = null;

    namedArgs?.onDragEnd?.();

    document.removeEventListener("mousemove", onMove);
    document.removeEventListener("touchmove", onMove);
    document.removeEventListener("mouseup", onEnd);
    document.removeEventListener("touchend", onEnd);
    document.body.classList.remove("is-dragging");
  }

  element.addEventListener("mousedown", onStart, { passive: false });
  element.addEventListener("touchstart", onStart, { passive: false });

  return () => {
    element.removeEventListener("mousedown", onStart);
    element.removeEventListener("touchstart", onStart);
    onEnd();
  };
});

const DRAGGING_CLASS = "is-dragging";
const POSITIONED_CLASS = "is-manually-positioned";

function pointerPosition(event) {
  if (event.touches?.length) {
    return {
      x: event.touches[0].clientX,
      y: event.touches[0].clientY,
    };
  }

  if (event.changedTouches?.length) {
    return {
      x: event.changedTouches[0].clientX,
      y: event.changedTouches[0].clientY,
    };
  }

  return {
    x: event.clientX,
    y: event.clientY,
  };
}

export class DragPanel {
  constructor(element, panelElement, boundarySelector = null) {
    this.element = element;
    this.panel = panelElement;
    this.boundarySelector = boundarySelector;
    this.animationFrameId = null;
    this.currentX = 0;
    this.currentY = 0;
  }

  start(event) {
    const { x, y } = pointerPosition(event);
    const panelRect = this.panel.getBoundingClientRect();

    const offsetParent = this.panel.offsetParent;
    const parentRect = offsetParent
      ? offsetParent.getBoundingClientRect()
      : { left: 0, top: 0 };
    this.parentOffsetX = parentRect.left;
    this.parentOffsetY = parentRect.top;

    let boundary = {
      left: 0,
      top: 0,
      right: window.innerWidth,
      bottom: window.innerHeight,
    };
    if (this.boundarySelector) {
      const el =
        this.element.closest(this.boundarySelector) ||
        document.querySelector(this.boundarySelector);
      if (el) {
        boundary = el.getBoundingClientRect();
      }
    }
    this.boundary = boundary;

    this.currentX = panelRect.left;
    this.currentY = panelRect.top;

    this.offsetX = x - this.currentX;
    this.offsetY = y - this.currentY;

    this.targetX = this.currentX;
    this.targetY = this.currentY;

    this.panel.classList.add(POSITIONED_CLASS);
    this.updateCSS();

    this.panel.classList.add(DRAGGING_CLASS);
  }

  move(event) {
    const { x, y } = pointerPosition(event);

    if (this.animationFrameId) {
      this.lastX = x;
      this.lastY = y;
      return;
    }

    this.animationFrameId = requestAnimationFrame(() => {
      const pointerX = this.lastX ?? x;
      const pointerY = this.lastY ?? y;

      this.lastX = this.lastY = null;
      this.updatePosition(pointerX, pointerY);
      this.animationFrameId = null;
    });
  }

  updatePosition(pointerX, pointerY) {
    const minX = this.boundary.left;
    const minY = this.boundary.top;
    const maxX = this.boundary.right - this.panel.offsetWidth;
    const maxY = this.boundary.bottom - this.panel.offsetHeight;

    let targetX = pointerX - this.offsetX;
    let targetY = pointerY - this.offsetY;

    targetX = Math.max(minX, Math.min(targetX, maxX));
    targetY = Math.max(minY, Math.min(targetY, maxY));

    const lerp = 0.3;
    this.currentX += (targetX - this.currentX) * lerp;
    this.currentY += (targetY - this.currentY) * lerp;

    this.updateCSS();

    this.targetX = targetX;
    this.targetY = targetY;
  }

  updateCSS() {
    const dpr = window.devicePixelRatio || 1;
    const tx = Math.round((this.currentX - this.parentOffsetX) * dpr) / dpr;
    const ty = Math.round((this.currentY - this.parentOffsetY) * dpr) / dpr;

    this.panel.style.setProperty("--drag-tx", `${tx}px`);
    this.panel.style.setProperty("--drag-ty", `${ty}px`);
  }

  end() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }

    this.currentX = this.targetX;
    this.currentY = this.targetY;
    this.updateCSS();

    this.panel.classList.remove(DRAGGING_CLASS);
  }
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { eq, not } from "discourse/truth-helpers";
import dTrapTab from "discourse/ui-kit/modifiers/d-trap-tab";
import { i18n } from "discourse-i18n";
import { updateWrapAttribute } from "../lib/composer-utils";
import { settingsMenuOptions } from "../lib/image-compare/menu";
import ImageCompareUiState from "../lib/image-compare/ui-state";
import {
  clampPosition,
  keyboardStep,
  normalizeConfig,
  positionFromPointer,
} from "../lib/image-compare/utils";
import didResize from "../modifiers/did-resize";
import ImageCompareToolbar, {
  TOOLBAR_SURFACE_SELECTOR,
} from "./image-compare-toolbar";

const ZOOM_MIN = 1;
const ZOOM_STEP = 0.5;
const CONTROLS_HIDE_DELAY = 2000;
const PAN_MOVE_THRESHOLD = 3;
const WHEEL_IDLE_DELAY = 150;
const FULLSCREEN_ANIM_MS = 300;
const FULLSCREEN_EASING = "cubic-bezier(0.4, 0, 0.22, 1)";
const INTERACTIVE_SELECTOR = ".d-ic__handle, .d-ic__zoom-btn";

let previewMenuIndex = 0;

export default class ImageCompare extends Component {
  @service menu;
  @service previewState;

  @tracked position;
  @tracked isDragging = false;
  @tracked isSelected = false;
  @tracked zoom = 1;
  @tracked panX = 0;
  @tracked panY = 0;
  @tracked controlsVisible = false;
  @tracked scale = 1;
  @tracked isFullscreen = false;

  @tracked isPanning = false;
  @tracked isPinching = false;
  @tracked isWheelZooming = false;

  wheelIdleTimer = null;
  containerElement = null;
  dragRect = null;
  settingsMenu = null;
  lastPosition = undefined;
  localUiState = new ImageCompareUiState();

  pointers = new Map();
  panMoved = false;
  panStart = null;
  pinchStart = null;
  hideControlsTimer = null;
  fullResLoaded = false;
  fullscreenClosing = false;
  fullscreenCloseTimer = null;
  fullscreenPortal = null;
  fullscreenReturnFocus = null;

  onFullscreenKeydown = (event) => {
    if (event.key === "Escape") {
      this.exitFullscreen();
    }
  };

  clickOutsideHandler = modifier((element) => {
    if (!this.args.data?.isPreview) {
      return;
    }

    const handler = (event) => {
      if (
        !this.isSelected ||
        element.contains(event.target) ||
        event.target.closest(TOOLBAR_SURFACE_SELECTOR)
      ) {
        return;
      }

      this.deselect();
    };

    document.addEventListener("pointerdown", handler, true);

    return () => {
      document.removeEventListener("pointerdown", handler, true);
    };
  });

  wheelHandler = modifier((element) => {
    const handler = (event) => this.onWheel(event);
    element.addEventListener("wheel", handler, { passive: false });

    return () => element.removeEventListener("wheel", handler);
  });

  constructor() {
    super(...arguments);

    const pos = this.initialPosition;
    this.lastPosition = pos;
    this.position = pos;

    previewMenuIndex++;
    this.menuId = previewMenuIndex;

    // Restore selection after preview re-render
    if (
      this.isPreview &&
      this.previewState.selectedWrapIndex !== null &&
      this.previewState.selectedWrapIndex === this.args.data?.wrapIndex
    ) {
      this.isSelected = true;
    }
  }

  willDestroy() {
    this.closeSettingsMenu();
    this.clearHideControlsTimer();

    if (this.wheelIdleTimer) {
      cancel(this.wheelIdleTimer);
      this.wheelIdleTimer = null;
    }

    if (this.fullscreenCloseTimer) {
      cancel(this.fullscreenCloseTimer);
      this.fullscreenCloseTimer = null;
    }

    if (this.isFullscreen) {
      document.removeEventListener("keydown", this.onFullscreenKeydown);
    }

    if (this.fullscreenPortal) {
      this.fullscreenPortal.remove();
      this.fullscreenPortal = null;
    }

    super.willDestroy(...arguments);
  }

  get isPreview() {
    return this.args.data?.isPreview;
  }

  get uiState() {
    if (this.args.data.uiState) {
      return this.args.data.uiState;
    }

    if (this.isPreview) {
      return this.previewState.stateFor(this.args.data.wrapIndex);
    }

    return this.localUiState;
  }

  get initialPosition() {
    const pos = this.args.data?.position || settings.default_position;
    return clampPosition(Number(pos));
  }

  get displayPosition() {
    const pos = this.initialPosition;

    if (pos !== this.lastPosition) {
      return pos;
    }

    return this.position;
  }

  get orientation() {
    return this.args.data?.orientation || settings.default_orientation;
  }

  get showLabels() {
    const showLabels = this.args.data?.showLabels;

    if (showLabels === null) {
      return settings.default_show_labels;
    }

    return showLabels;
  }

  get beforeLabel() {
    if (!this.showLabels) {
      return null;
    }

    return (
      this.args.data?.beforeLabel ||
      i18n(themePrefix("image_compare.before_label"))
    );
  }

  get afterLabel() {
    if (!this.showLabels) {
      return null;
    }

    return (
      this.args.data?.afterLabel ||
      i18n(themePrefix("image_compare.after_label"))
    );
  }

  get ariaLabel() {
    return i18n(themePrefix("image_compare.aria_label"));
  }

  get zoomInLabel() {
    return i18n(themePrefix("image_compare.zoom.in"));
  }

  get zoomOutLabel() {
    return i18n(themePrefix("image_compare.zoom.out"));
  }

  get resetZoomLabel() {
    return i18n(themePrefix("image_compare.zoom.reset"));
  }

  get lightboxLabel() {
    return i18n(themePrefix("image_compare.lightbox.open"));
  }

  get fullscreenLabel() {
    const exit = this.isFullscreen || this.isFullscreenChild;
    return i18n(
      themePrefix(
        exit
          ? "image_compare.fullscreen.exit"
          : "image_compare.fullscreen.enter"
      )
    );
  }

  get labelPosition() {
    return this.args.data?.labelPosition || settings.default_label_position;
  }

  get handleStyle() {
    return this.args.data?.handleStyle || settings.default_handle_style;
  }

  get handleKnobClass() {
    const map = {
      circle: "d-ic__circle",
      grabber: "d-ic__grabber",
    };
    return map[this.handleStyle] ?? null;
  }

  get isZoomed() {
    return this.zoom > 1;
  }

  get atMinZoom() {
    return this.zoom <= ZOOM_MIN;
  }

  get maxZoom() {
    const value = parseInt(settings.max_zoom, 10);
    return Number.isFinite(value) && value >= 2 ? value : 5;
  }

  get atMaxZoom() {
    return this.zoom >= this.maxZoom;
  }

  get zoomEnabled() {
    return settings.enable_zoom;
  }

  get containerStyle() {
    const pos = this.displayPosition / 100;
    const handleColor =
      this.args.data?.handleColor || settings.default_handle_color;
    const color = handleColor ? `; --ic-line-color: ${handleColor}` : "";

    return trustHTML(
      `--ic-pos: ${pos}${color}; --ic-zoom: ${this.zoom}; --ic-pan-x: ${this.panX}px; --ic-pan-y: ${this.panY}px; --ic-scale: ${this.scale}`
    );
  }

  get beforeImage() {
    return this.args.data?.images?.before;
  }

  get afterImage() {
    return this.args.data?.images?.after;
  }

  #resolveSrc(image) {
    if (!image) {
      return null;
    }

    return this.isFullscreenChild
      ? (image.fullSrc ?? image.previewSrc)
      : image.previewSrc;
  }

  #resolveMarkup(image) {
    const markup = this.isFullscreenChild
      ? image?.fullMarkup
      : image?.previewMarkup;

    return markup ? trustHTML(markup) : null;
  }

  get beforeSrc() {
    return this.#resolveSrc(this.beforeImage);
  }

  get afterSrc() {
    return this.#resolveSrc(this.afterImage);
  }

  get beforeMarkup() {
    return this.#resolveMarkup(this.beforeImage);
  }

  get afterMarkup() {
    return this.#resolveMarkup(this.afterImage);
  }

  get beforeAlt() {
    return this.beforeImage?.alt || this.beforeLabel || "";
  }

  get afterAlt() {
    return this.afterImage?.alt || this.afterLabel || "";
  }

  get hasLightbox() {
    return (
      !this.isPreview &&
      !this.isFullscreenChild &&
      !!(this.beforeImage?.previewMarkup || this.afterImage?.previewMarkup)
    );
  }

  get beforeClipStyle() {
    const pos = this.displayPosition;
    const value =
      this.orientation === "horizontal"
        ? `inset(0 ${100 - pos}% 0 0)`
        : `inset(0 0 ${100 - pos}% 0)`;

    return trustHTML(`clip-path: ${value};`);
  }

  get afterClipStyle() {
    const pos = this.displayPosition;
    const value =
      this.orientation === "horizontal"
        ? `inset(0 0 0 ${pos}%)`
        : `inset(${pos}% 0 0 0)`;

    return trustHTML(`clip-path: ${value};`);
  }

  get handlePosition() {
    const pos = this.displayPosition;

    if (this.orientation === "horizontal") {
      return trustHTML(`left: ${pos}%;`);
    } else {
      return trustHTML(`top: ${pos}%;`);
    }
  }

  get currentConfig() {
    return normalizeConfig(this.args.data);
  }

  get toolbarData() {
    return {
      getConfig: () => this.currentConfig,
      updateSetting: this.updateMarkdownSetting,
      menuIdentifier: `preview-ic-settings-${this.menuId}`,
      wrapIndex: this.args.data?.wrapIndex,
      isPreview: this.isPreview,
      uiState: this.uiState,
    };
  }

  get viewportElement() {
    return this.containerElement?.querySelector(".d-ic__viewport");
  }

  get viewportRect() {
    return this.viewportElement?.getBoundingClientRect();
  }

  get viewportCenter() {
    const rect = this.viewportRect;
    return rect ? [rect.width / 2, rect.height / 2] : [0, 0];
  }

  @action
  setup(element) {
    this.containerElement = element;

    if (this.isSelected) {
      this.openSettingsMenu();
    }
  }

  @action
  onPointerDown(event) {
    if (event?.button !== 0) {
      return;
    }

    event.preventDefault();
    event.target.setPointerCapture(event.pointerId);
    event.target.closest(".d-ic__handle")?.focus();

    this.isDragging = true;

    const viewport = this.viewportElement;
    if (!viewport) {
      return;
    }

    this.dragRect = viewport.getBoundingClientRect();
    this.updatePosition(
      positionFromPointer(event, this.dragRect, this.orientation)
    );
  }

  @action
  onPointerMove(event) {
    if (!this.isDragging || !this.dragRect) {
      return;
    }
    this.updatePosition(
      positionFromPointer(event, this.dragRect, this.orientation)
    );
  }

  @action
  onPointerUp() {
    if (!this.isDragging) {
      return;
    }
    this.isDragging = false;
    this.dragRect = null;
  }

  @action
  onViewportClick(event) {
    if (this.panMoved) {
      this.panMoved = false;
      return;
    }

    if (event.target.closest(INTERACTIVE_SELECTOR)) {
      return;
    }

    if (this.isPreview && !this.isSelected) {
      this.select();
    }
  }

  @action
  onKeyDown(event) {
    if (event.ctrlKey || event.altKey || event.metaKey) {
      return;
    }

    if (this.zoomEnabled) {
      if (event.key === "+" || event.key === "=") {
        event.preventDefault();
        this.zoomIn();
        return;
      }
      if (event.key === "-") {
        event.preventDefault();
        this.zoomOut();
        return;
      }
      if (event.key === "0") {
        event.preventDefault();
        this.resetZoom();
        return;
      }
    }

    const newPos = keyboardStep(
      event.key,
      this.position,
      event.shiftKey,
      this.orientation
    );

    if (newPos !== null) {
      event.preventDefault();
      this.updatePosition(newPos);
    }
  }

  updatePosition(pos) {
    this.lastPosition = this.initialPosition;
    this.position = clampPosition(pos);
  }

  clampPan(zoom = this.zoom) {
    if (zoom <= 1) {
      this.panX = 0;
      this.panY = 0;
      return;
    }

    const rect = this.viewportRect;
    if (!rect) {
      return;
    }

    const minX = (1 - zoom) * rect.width;
    const minY = (1 - zoom) * rect.height;

    this.panX = Math.min(0, Math.max(minX, this.panX));
    this.panY = Math.min(0, Math.max(minY, this.panY));
  }

  setZoom(newZoom, anchorX = null, anchorY = null) {
    const clamped = Math.max(ZOOM_MIN, Math.min(this.maxZoom, newZoom));

    if (clamped > ZOOM_MIN) {
      this.loadFullResolution();
    }

    if (clamped === this.zoom) {
      return;
    }

    if (anchorX != null && anchorY != null) {
      const ratio = clamped / this.zoom;
      this.panX = anchorX - ratio * (anchorX - this.panX);
      this.panY = anchorY - ratio * (anchorY - this.panY);
    }

    this.zoom = clamped;

    this.clampPan();
    this.showControls();
  }

  @action
  zoomIn() {
    const [cx, cy] = this.viewportCenter;
    this.setZoom(this.zoom + ZOOM_STEP, cx, cy);
  }

  @action
  zoomOut() {
    const [cx, cy] = this.viewportCenter;
    this.setZoom(this.zoom - ZOOM_STEP, cx, cy);
  }

  @action
  resetZoom() {
    this.zoom = 1;
    this.panX = 0;
    this.panY = 0;
    this.scheduleHideControls();
  }

  @action
  toggleFullscreen() {
    if (this.isFullscreenChild) {
      this.args.data?.onExitFullscreen?.();
    } else if (this.isFullscreen) {
      this.exitFullscreen();
    } else {
      this.enterFullscreen();
    }
  }

  get isFullscreenChild() {
    return this.args.data?.isFullscreenChild;
  }

  get showFullscreenButton() {
    return !this.isPreview && settings.enable_fullscreen;
  }

  get showLightboxButton() {
    return settings.enable_lightbox && this.hasLightbox;
  }

  get showControlsBar() {
    return (
      this.zoomEnabled || this.showLightboxButton || this.showFullscreenButton
    );
  }

  get showControlsSeparator() {
    return (
      this.zoomEnabled && (this.showLightboxButton || this.showFullscreenButton)
    );
  }

  get fullscreenIcon() {
    return this.isFullscreenChild ? "discourse-compress" : "discourse-expand";
  }

  get fullscreenChildData() {
    return {
      ...this.args.data,
      isFullscreenChild: true,
      onExitFullscreen: () => this.exitFullscreen(),
    };
  }

  get prefersReducedMotion() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  }

  enterFullscreen() {
    if (this.isFullscreen) {
      return;
    }
    if (!this.fullscreenPortal) {
      this.fullscreenPortal = document.createElement("div");
      document.body.appendChild(this.fullscreenPortal);
    }
    this.fullscreenReturnFocus = document.activeElement;
    this.isFullscreen = true;
    document.addEventListener("keydown", this.onFullscreenKeydown);

    requestAnimationFrame(() => this.#animateFullscreen(false));
  }

  exitFullscreen() {
    if (!this.isFullscreen || this.fullscreenClosing) {
      return;
    }
    this.fullscreenClosing = true;

    if (this.#animateFullscreen(true)) {
      this.fullscreenCloseTimer = later(
        this,
        this.#finishClose,
        FULLSCREEN_ANIM_MS
      );
    } else {
      this.#finishClose();
    }
  }

  #finishClose() {
    this.fullscreenCloseTimer = null;
    this.fullscreenClosing = false;
    this.isFullscreen = false;
    document.removeEventListener("keydown", this.onFullscreenKeydown);
    this.fullscreenReturnFocus?.focus?.();
    this.fullscreenReturnFocus = null;
  }

  #animateFullscreen(closing) {
    if (this.prefersReducedMotion) {
      return false;
    }

    const source = this.viewportElement;
    const overlay = this.fullscreenPortal?.querySelector(".d-ic-fs");
    const target = overlay?.querySelector(".d-ic__viewport");
    if (!source || !overlay || !target) {
      return false;
    }

    const flip = this.#flipTransform(
      source.getBoundingClientRect(),
      target.getBoundingClientRect()
    );
    const options = {
      duration: FULLSCREEN_ANIM_MS,
      easing: FULLSCREEN_EASING,
      fill: closing ? "forwards" : "none",
    };
    const opaque = "rgba(0, 0, 0, 0.8)";
    const clear = "rgba(0, 0, 0, 0)";

    overlay.animate(
      closing
        ? [{ backgroundColor: opaque }, { backgroundColor: clear }]
        : [{ backgroundColor: clear }, { backgroundColor: opaque }],
      options
    );

    // The caption can't be morphed with the image, so fade it instead.
    overlay
      .querySelector(".d-ic__caption")
      ?.animate(
        closing
          ? [{ opacity: 1 }, { opacity: 0 }]
          : [{ opacity: 0 }, { opacity: 1 }],
        options
      );

    return target.animate(
      (closing ? ["none", flip] : [flip, "none"]).map((transform) => ({
        transformOrigin: "top left",
        transform,
      })),
      options
    );
  }

  #flipTransform(from, to) {
    const dx = from.left - to.left;
    const dy = from.top - to.top;
    const sx = to.width ? from.width / to.width : 1;
    const sy = to.height ? from.height / to.height : 1;
    return `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;
  }

  @action
  onOverlayClick(event) {
    if (!event.target.closest(".d-ic__viewport")) {
      this.exitFullscreen();
    }
  }

  loadFullResolution() {
    if (this.fullResLoaded) {
      return;
    }
    this.fullResLoaded = true;

    const swap = (selector, image) => {
      const fullSrc = image?.fullSrc;
      if (!fullSrc) {
        return;
      }

      const img = this.containerElement?.querySelector(selector);
      if (!img) {
        return;
      }

      img.removeAttribute("srcset");
      img.src = fullSrc;
    };

    swap(".d-ic__image--before", this.beforeImage);
    swap(".d-ic__image--after", this.afterImage);
  }

  @action
  openLightbox() {
    const anchor =
      this.containerElement?.querySelector(".d-ic__clip--before a.lightbox") ??
      this.containerElement?.querySelector("a.lightbox");
    anchor?.click();
  }

  onWheel(event) {
    if (!this.zoomEnabled || !event.ctrlKey) {
      return;
    }
    event.preventDefault();
    const rect = this.viewportRect;
    if (!rect) {
      return;
    }
    const ax = event.clientX - rect.left;
    const ay = event.clientY - rect.top;
    const factor = Math.exp(-event.deltaY * 0.005);
    this.isWheelZooming = true;
    if (this.wheelIdleTimer) {
      cancel(this.wheelIdleTimer);
    }
    this.wheelIdleTimer = later(this, this.endWheelZoom, WHEEL_IDLE_DELAY);
    this.setZoom(this.zoom * factor, ax, ay);
  }

  @action
  endWheelZoom() {
    this.isWheelZooming = false;
    this.wheelIdleTimer = null;
  }

  @action
  onPanPointerDown(event) {
    if (event.target.closest(INTERACTIVE_SELECTOR)) {
      return;
    }

    this.pointers.set(event.pointerId, {
      x: event.clientX,
      y: event.clientY,
    });

    if (this.pointers.size === 2 && this.zoomEnabled) {
      const [a, b] = [...this.pointers.values()];
      this.pinchStart = {
        distance: Math.hypot(a.x - b.x, a.y - b.y) || 1,
        zoom: this.zoom,
      };
      this.isPanning = false;
      this.isPinching = true;
      this.panStart = null;
      return;
    }

    if (this.zoom > 1 && event.button === 0) {
      event.preventDefault();
      try {
        event.target.setPointerCapture(event.pointerId);
      } catch {
        // ignore: pointer capture may fail on detached targets
      }
      this.isPanning = true;
      this.panMoved = false;
      this.panStart = {
        x: event.clientX,
        y: event.clientY,
        panX: this.panX,
        panY: this.panY,
      };
    }

    this.showControls();
  }

  @action
  onPanPointerMove(event) {
    if (this.pointers.has(event.pointerId)) {
      this.pointers.set(event.pointerId, {
        x: event.clientX,
        y: event.clientY,
      });
    }

    if (this.pinchStart && this.pointers.size === 2) {
      const [a, b] = [...this.pointers.values()];
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      const ratio = dist / this.pinchStart.distance;

      const rect = this.viewportRect;
      if (!rect) {
        return;
      }

      const midX = (a.x + b.x) / 2 - rect.left;
      const midY = (a.y + b.y) / 2 - rect.top;
      this.setZoom(this.pinchStart.zoom * ratio, midX, midY);

      return;
    }

    if (!this.isPanning || !this.panStart) {
      return;
    }

    const dx = event.clientX - this.panStart.x;
    const dy = event.clientY - this.panStart.y;

    if (Math.hypot(dx, dy) > PAN_MOVE_THRESHOLD) {
      this.panMoved = true;
    }

    this.panX = this.panStart.panX + dx;
    this.panY = this.panStart.panY + dy;
    this.clampPan();
  }

  @action
  onPanPointerUp(event) {
    this.pointers.delete(event.pointerId);

    if (this.pointers.size < 2) {
      this.pinchStart = null;
      this.isPinching = false;

      // Hand off from pinch to single-finger pan: if a finger is still down
      // and the image is zoomed, resume panning from its current position.
      if (this.pointers.size === 1 && this.zoom > 1) {
        const [remaining] = [...this.pointers.values()];
        this.isPanning = true;
        this.panMoved = false;
        this.panStart = {
          x: remaining.x,
          y: remaining.y,
          panX: this.panX,
          panY: this.panY,
        };
      }
    }

    if (this.pointers.size === 0) {
      this.isPanning = false;
      this.panStart = null;
      this.panMoved = false;
    }

    this.scheduleHideControls();
  }

  @action
  onViewportPointerEnter() {
    this.showControls();
    this.scheduleHideControls();
  }

  @action
  onControlsPointerEnter() {
    this.showControls();
  }

  @action
  onControlsPointerLeave() {
    this.scheduleHideControls();
  }

  showControls() {
    this.controlsVisible = true;
    this.clearHideControlsTimer();
  }

  scheduleHideControls() {
    if (this.zoom > 1) {
      return;
    }

    this.clearHideControlsTimer();
    this.hideControlsTimer = later(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.controlsVisible = false;
      this.hideControlsTimer = null;
    }, CONTROLS_HIDE_DELAY);
  }

  clearHideControlsTimer() {
    if (this.hideControlsTimer) {
      cancel(this.hideControlsTimer);
      this.hideControlsTimer = null;
    }
  }

  @action
  updateMarkdownSetting(key, value) {
    const wrapIndex = this.args.data?.wrapIndex;
    updateWrapAttribute("image-compare", wrapIndex, key, value);
  }

  @action
  async select() {
    this.isSelected = true;
    this.previewState.setSelectedWrapIndex(this.args.data?.wrapIndex);

    await this.openSettingsMenu();
  }

  @action
  deselect() {
    this.isSelected = false;
    this.previewState.setSelectedWrapIndex(null);
    this.previewState.clearSavedDragPosition(
      `ic-settings-pos-${this.args.data?.wrapIndex}`
    );
    this.closeSettingsMenu();
  }

  async openSettingsMenu() {
    if (this.settingsMenu) {
      return;
    }

    const anchor =
      this.containerElement?.querySelector(".d-ic__viewport") ??
      this.containerElement;
    if (!anchor) {
      return;
    }

    const instance = await this.menu.newInstance(
      anchor,
      settingsMenuOptions({
        identifier: `preview-ic-settings-${this.menuId}`,
        component: ImageCompareToolbar,
        data: this.toolbarData,
        portalOutletElement:
          this.containerElement?.closest(".d-ic-container") ??
          document.querySelector(".d-editor-preview"),
      })
    );

    if (this.isDestroying || this.isDestroyed) {
      this.menu.close(instance);
      return;
    }

    this.settingsMenu = instance;
    await this.settingsMenu.show();
  }

  closeSettingsMenu() {
    if (this.settingsMenu) {
      this.menu.close(this.settingsMenu);
      this.settingsMenu = null;
    }
  }

  calculateScale(width) {
    this.scale = Math.max(0.6, Math.min(1, width / 500));
  }

  @action
  handleResize(entry) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.calculateScale(entry.contentRect.width);

    const labels = entry.target?.querySelectorAll(".d-ic__label");
    const cornerButtons = entry.target?.parentElement
      ?.closest(".composer-image_compare-node")
      ?.querySelectorAll('[data-identifier^="composer-ic-toolbar"]');

    const labelWidth = labels
      ? [...labels].reduce((width, element) => width + element.offsetWidth, 0)
      : 0;
    const cornerButtonWidth = cornerButtons
      ? [...cornerButtons].reduce(
          (width, element) => width + element.offsetWidth,
          0
        )
      : 0;

    this.uiState.toolbarCollapsed =
      entry.contentRect.width - Math.max(labelWidth, cornerButtonWidth) < 300;

    this.clampPan();
  }

  <template>
    <figure
      class={{concatClass
        "d-ic"
        (if (eq this.orientation "vertical") "d-ic--vertical")
        (if this.isDragging "d-ic--dragging")
        (concat "d-ic--handle-" this.handleStyle)
        (if this.showLabels (concat "d-ic--labels-" this.labelPosition))
        (if this.isSelected "d-ic--preview-selected")
        (if this.isZoomed "d-ic--zoomed")
      }}
      role="group"
      aria-label={{this.ariaLabel}}
      style={{this.containerStyle}}
      {{didInsert this.setup}}
      {{didResize this.handleResize}}
      {{this.clickOutsideHandler}}
    >
      {{! template-lint-disable no-invalid-interactive }}
      {{! template-lint-disable no-pointer-down-event-binding }}
      <div
        class={{concatClass
          "d-ic__viewport"
          (if this.isPanning "is-panning")
          (if this.isPinching "is-pinching")
          (if this.isWheelZooming "is-wheel-zooming")
        }}
        {{on "click" this.onViewportClick}}
        {{on "pointerdown" this.onPanPointerDown}}
        {{on "pointermove" this.onPanPointerMove}}
        {{on "pointerup" this.onPanPointerUp}}
        {{on "pointercancel" this.onPanPointerUp}}
        {{on "pointerenter" this.onViewportPointerEnter}}
        {{this.wheelHandler}}
      >
        <div
          class="d-ic__clip d-ic__clip--before"
          style={{this.beforeClipStyle}}
        >
          {{#if this.beforeMarkup}}
            {{this.beforeMarkup}}
          {{else}}
            <img
              class="d-ic__image d-ic__image--before lightbox"
              src={{this.beforeSrc}}
              alt={{this.beforeAlt}}
              draggable="false"
            />
          {{/if}}
        </div>

        <div class="d-ic__clip d-ic__clip--after" style={{this.afterClipStyle}}>
          {{#if this.afterMarkup}}
            {{this.afterMarkup}}
          {{else}}
            <img
              class="d-ic__image d-ic__image--after lightbox"
              src={{this.afterSrc}}
              alt={{this.afterAlt}}
              draggable="false"
            />
          {{/if}}
        </div>

        {{! template-lint-disable no-pointer-down-event-binding }}
        <div
          class="d-ic__handle"
          role="slider"
          tabindex="0"
          aria-valuenow={{this.displayPosition}}
          aria-valuemin="0"
          aria-valuemax="100"
          aria-orientation={{this.orientation}}
          aria-label={{this.ariaLabel}}
          style={{this.handlePosition}}
          {{on "pointerdown" this.onPointerDown}}
          {{on "pointermove" this.onPointerMove}}
          {{on "pointerup" this.onPointerUp}}
          {{on "pointercancel" this.onPointerUp}}
          {{on "keydown" this.onKeyDown}}
        >
          <div class="d-ic__line"></div>
          {{#if this.handleKnobClass}}
            <div class={{this.handleKnobClass}}></div>
          {{/if}}
          <div class="d-ic__arrows">
            {{icon "ict-arrow" class="d-ic__arrow d-ic__arrow--left"}}
            {{icon "ict-arrow" class="d-ic__arrow d-ic__arrow--right"}}
          </div>
          <div class="d-ic__line"></div>
        </div>

        {{#if this.beforeLabel}}
          <span
            class="d-ic__label d-ic__label--before"
            dir="auto"
            aria-hidden="true"
          >{{this.beforeLabel}}</span>
        {{/if}}

        {{#if this.afterLabel}}
          <span
            class="d-ic__label d-ic__label--after"
            dir="auto"
            aria-hidden="true"
          >{{this.afterLabel}}</span>
        {{/if}}

        {{#if this.showControlsBar}}
          <div
            class={{concatClass
              "d-ic__zoom-controls"
              (if this.controlsVisible "is-visible")
            }}
            {{on "pointerenter" this.onControlsPointerEnter}}
            {{on "pointerleave" this.onControlsPointerLeave}}
          >
            {{#if this.zoomEnabled}}
              <DButton
                class="d-ic__zoom-btn"
                aria-label={{this.zoomInLabel}}
                disabled={{this.atMaxZoom}}
                @action={{this.zoomIn}}
                @icon="magnifying-glass-plus"
                @translatedTitle={{this.zoomInLabel}}
              />
              <DButton
                class="d-ic__zoom-btn"
                aria-label={{this.zoomOutLabel}}
                disabled={{this.atMinZoom}}
                @action={{this.zoomOut}}
                @icon="magnifying-glass-minus"
                @translatedTitle={{this.zoomOutLabel}}
              />
              <DButton
                class="d-ic__zoom-btn"
                aria-label={{this.resetZoomLabel}}
                disabled={{not this.isZoomed}}
                @action={{this.resetZoom}}
                @icon="rotate-left"
                @translatedTitle={{this.resetZoomLabel}}
              />
            {{/if}}
            {{#if this.showControlsSeparator}}
              <div class="d-ic__controls-sep" aria-hidden="true"></div>
            {{/if}}
            {{#if this.showLightboxButton}}
              <DButton
                class="d-ic__zoom-btn d-ic__lightbox-btn"
                aria-label={{this.lightboxLabel}}
                @action={{this.openLightbox}}
                @icon="images"
                @translatedTitle={{this.lightboxLabel}}
              />
            {{/if}}
            {{#if this.showFullscreenButton}}
              <DButton
                class="d-ic__zoom-btn d-ic__fullscreen-btn"
                aria-label={{this.fullscreenLabel}}
                @action={{this.toggleFullscreen}}
                @icon={{this.fullscreenIcon}}
                @translatedTitle={{this.fullscreenLabel}}
              />
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{#if @data.caption}}
        <figcaption
          class="d-ic__caption"
          dir="auto"
        >{{@data.caption}}</figcaption>
      {{/if}}
    </figure>

    {{#if this.isFullscreen}}
      {{#in-element this.fullscreenPortal}}
        {{! template-lint-disable no-invalid-interactive }}
        <div
          class="d-ic-fs"
          role="dialog"
          aria-modal="true"
          aria-label={{this.fullscreenLabel}}
          tabindex="-1"
          {{on "click" this.onOverlayClick}}
          {{dTrapTab}}
        >
          <ImageCompare @data={{this.fullscreenChildData}} />
          <DButton
            class="d-ic-fs__close"
            aria-label={{this.fullscreenLabel}}
            @action={{this.toggleFullscreen}}
            @icon="xmark"
          />
        </div>
      {{/in-element}}
    {{/if}}
  </template>
}

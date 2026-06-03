/**
 * Clamps a position value to the 0..100 range.
 * @param {number} value
 * @returns {number}
 */
export function clampPosition(value) {
  if (!Number.isFinite(value)) {
    return 50;
  }
  return Math.max(0, Math.min(100, value));
}

/**
 * Computes slider position (0..100) from a pointer event
 * relative to a container rect and orientation.
 *
 * @param {PointerEvent} event
 * @param {DOMRect} rect
 * @param {"horizontal" | "vertical"} orientation
 * @returns {number}
 */
export function positionFromPointer(event, rect, orientation) {
  const dimension = orientation === "horizontal" ? rect.width : rect.height;
  if (dimension === 0) {
    return 50;
  }

  const offset =
    orientation === "horizontal"
      ? event.clientX - rect.left
      : event.clientY - rect.top;

  return clampPosition((offset / dimension) * 100);
}

/**
 * Computes the new slider position after a keyboard event.
 * Returns null if the key is not handled.
 *
 * @param {string} key - The keyboard event key
 * @param {number} current - Current position (0..100)
 * @param {boolean} shiftKey - Whether shift is held
 * @param {"horizontal" | "vertical"} orientation
 * @returns {number | null}
 */
export function keyboardStep(key, current, shiftKey, orientation) {
  const step = shiftKey ? 10 : 1;
  let result = null;

  if (orientation === "horizontal") {
    if (key === "ArrowLeft") {
      result = current - step;
    } else if (key === "ArrowRight") {
      result = current + step;
    }
  } else {
    if (key === "ArrowUp") {
      result = current - step;
    } else if (key === "ArrowDown") {
      result = current + step;
    }
  }

  if (key === "Home") {
    result = 0;
  } else if (key === "End") {
    result = 100;
  }

  if (result !== null) {
    return clampPosition(result);
  }

  return null;
}

const VALID_ORIENTATIONS = ["horizontal", "vertical"];
const VALID_HANDLE_STYLES = ["default", "circle", "thin", "grabber"];
const HANDLE_COLOR_REGEX = /^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

/**
 * Maps the legacy direction flags to a slider orientation.
 * @param {{ vertical: boolean, horizontal: boolean }} flags
 * @returns {"vertical" | "horizontal" | null}
 */
export function legacyOrientation({ vertical, horizontal }) {
  if (vertical) {
    return "vertical";
  }
  if (horizontal) {
    return "horizontal";
  }
  return null;
}

export function isValidHandleColor(value) {
  if (value == null || value === "") {
    return true;
  }
  return typeof value === "string" && HANDLE_COLOR_REGEX.test(value);
}

function parseBoolean(value) {
  return value == null ? null : value === true || value === "true";
}

export function normalizeConfig(attrs) {
  const raw = attrs || {};

  let orientation = "horizontal";
  if (raw.orientation && VALID_ORIENTATIONS.includes(raw.orientation)) {
    orientation = raw.orientation;
  }

  let handleStyle = "default";
  if (raw.handleStyle && VALID_HANDLE_STYLES.includes(raw.handleStyle)) {
    handleStyle = raw.handleStyle;
  }

  let position = 50;
  if (raw.position !== undefined) {
    const parsed = parseFloat(raw.position);
    if (Number.isFinite(parsed)) {
      position = clampPosition(parsed);
    }
  }

  return {
    orientation,
    position,
    handleStyle,
    handleColor: isValidHandleColor(raw.handleColor)
      ? raw.handleColor || null
      : null,
    showLabels: parseBoolean(raw.showLabels),
    labelPosition: raw.labelPosition || "end",
    beforeLabel: raw.beforeLabel || null,
    afterLabel: raw.afterLabel || null,
    caption: raw.caption || null,
  };
}

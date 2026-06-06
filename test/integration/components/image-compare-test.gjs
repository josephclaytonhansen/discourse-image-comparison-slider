import {
  click,
  find,
  render,
  triggerEvent,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ImageCompare from "../../../discourse/components/image-compare";

const IMG =
  "data:image/svg+xml;charset=utf-8," +
  encodeURIComponent(
    "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='100'></svg>"
  );

function slot(alt) {
  return {
    previewSrc: IMG,
    fullSrc: null,
    previewMarkup: null,
    fullMarkup: null,
    alt,
  };
}

function compareData(overrides = {}) {
  return {
    images: { before: slot("before"), after: slot("after") },
    ...overrides,
  };
}

async function waitForLayout() {
  await waitUntil(
    () => find(".d-ic__viewport")?.getBoundingClientRect().width >= 200,
    { timeout: 2000 }
  );
}

function applyDefaultSettings() {
  settings.enable_zoom = true;
  settings.enable_fullscreen = true;
  settings.enable_lightbox = false;
  settings.max_zoom = 5;
  settings.default_orientation = "horizontal";
  settings.default_position = 50;
  settings.default_handle_style = "default";
  settings.default_handle_color = "";
  settings.default_label_position = "end";
  settings.default_show_labels = true;
}

module("Integration | Component | ImageCompare", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    applyDefaultSettings();
  });

  test("renders both images and an accessible slider handle", async function (assert) {
    const data = compareData();
    await render(<template><ImageCompare @data={{data}} /></template>);

    assert
      .dom(".d-ic__image--before")
      .hasAttribute("src", IMG, "before image renders");
    assert.dom(".d-ic__image--after").exists("after image renders");
    assert.dom(".d-ic").hasAttribute("role", "group", "figure is a group");
    assert
      .dom(".d-ic__handle")
      .hasAttribute("role", "slider", "handle exposes slider role");
    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "50", "starts at the default position");
    assert.dom(".d-ic__handle").hasAria("valuemin", "0", "min is 0");
    assert.dom(".d-ic__handle").hasAria("valuemax", "100", "max is 100");
    assert
      .dom(".d-ic__handle")
      .hasAria("orientation", "horizontal", "defaults to horizontal");
  });

  test("honors an explicit position and vertical orientation", async function (assert) {
    const data = compareData({ position: 30, orientation: "vertical" });
    await render(<template><ImageCompare @data={{data}} /></template>);

    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "30", "uses the provided position");
    assert
      .dom(".d-ic__handle")
      .hasAria("orientation", "vertical", "orientation is vertical");
    assert
      .dom(".d-ic")
      .hasClass("d-ic--vertical", "figure gets the vertical modifier");
  });

  test("arrow keys move the divider and clamp at the edges", async function (assert) {
    const data = compareData({ position: 50 });
    await render(<template><ImageCompare @data={{data}} /></template>);

    await triggerKeyEvent(".d-ic__handle", "keydown", "ArrowRight");
    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "51", "ArrowRight moves +1");

    await triggerKeyEvent(".d-ic__handle", "keydown", "ArrowLeft", {
      shiftKey: true,
    });
    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "41", "shift+ArrowLeft moves -10");

    await triggerKeyEvent(".d-ic__handle", "keydown", "Home");
    assert.dom(".d-ic__handle").hasAria("valuenow", "0", "Home jumps to 0");

    await triggerKeyEvent(".d-ic__handle", "keydown", "ArrowLeft");
    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "0", "position clamps at 0");

    await triggerKeyEvent(".d-ic__handle", "keydown", "End");
    assert.dom(".d-ic__handle").hasAria("valuenow", "100", "End jumps to 100");
  });

  test("vertical orientation uses up/down arrows", async function (assert) {
    const data = compareData({ position: 50, orientation: "vertical" });
    await render(<template><ImageCompare @data={{data}} /></template>);

    await triggerKeyEvent(".d-ic__handle", "keydown", "ArrowDown");
    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "51", "ArrowDown moves +1 when vertical");

    await triggerKeyEvent(".d-ic__handle", "keydown", "ArrowUp");
    assert
      .dom(".d-ic__handle")
      .hasAria("valuenow", "50", "ArrowUp moves -1 when vertical");
  });

  test("dragging the handle moves the divider", async function (assert) {
    sinon.stub(Element.prototype, "setPointerCapture");
    sinon.stub(Element.prototype, "releasePointerCapture");

    const data = compareData({ position: 50 });
    await render(<template><ImageCompare @data={{data}} /></template>);
    await waitForLayout();

    const rect = find(".d-ic__viewport").getBoundingClientRect();
    const y = rect.top + rect.height / 2;

    await triggerEvent(".d-ic__handle", "pointerdown", {
      pointerId: 1,
      button: 0,
      buttons: 1,
      clientX: rect.left + rect.width / 2,
      clientY: y,
    });
    await triggerEvent(".d-ic__handle", "pointermove", {
      pointerId: 1,
      clientX: rect.left + rect.width * 0.75,
      clientY: y,
    });
    await triggerEvent(".d-ic__handle", "pointerup", { pointerId: 1 });

    const valuenow = parseFloat(
      find(".d-ic__handle").getAttribute("aria-valuenow")
    );
    assert.true(
      Math.abs(valuenow - 75) <= 1,
      `divider follows the pointer (expected ~75, got ${valuenow})`
    );
  });

  function zoomLevel() {
    return find(".d-ic").style.getPropertyValue("--ic-zoom").trim();
  }

  function zoomButton(icon) {
    return find(`.d-ic__zoom-controls .d-icon-${icon}`).closest("button");
  }

  test("zoom buttons step, clamp, disable, and reset", async function (assert) {
    settings.max_zoom = 2;
    const data = compareData();
    await render(<template><ImageCompare @data={{data}} /></template>);

    assert.strictEqual(zoomLevel(), "1", "starts at zoom 1");
    assert
      .dom(zoomButton("magnifying-glass-minus"))
      .isDisabled("zoom-out disabled at min");

    await click(zoomButton("magnifying-glass-plus"));
    assert.strictEqual(zoomLevel(), "1.5", "zoom-in steps by 0.5");

    await click(zoomButton("magnifying-glass-plus"));
    assert.strictEqual(zoomLevel(), "2", "zoom reaches max_zoom");
    assert
      .dom(zoomButton("magnifying-glass-plus"))
      .isDisabled("zoom-in disabled at max");

    await click(zoomButton("rotate-left"));
    assert.strictEqual(zoomLevel(), "1", "reset returns to 1");
  });

  test("zoom keyboard shortcuts on the handle", async function (assert) {
    const data = compareData();
    await render(<template><ImageCompare @data={{data}} /></template>);

    await triggerKeyEvent(".d-ic__handle", "keydown", "=");
    assert.strictEqual(zoomLevel(), "1.5", "= zooms in");

    await triggerKeyEvent(".d-ic__handle", "keydown", "-");
    assert.strictEqual(zoomLevel(), "1", "- zooms out");

    await triggerKeyEvent(".d-ic__handle", "keydown", "=");
    await triggerKeyEvent(".d-ic__handle", "keydown", "0");
    assert.strictEqual(zoomLevel(), "1", "0 resets zoom");
  });

  test("enable_zoom: false hides the zoom controls", async function (assert) {
    settings.enable_zoom = false;
    settings.enable_fullscreen = false;
    const data = compareData();
    await render(<template><ImageCompare @data={{data}} /></template>);

    assert
      .dom(".d-ic__zoom-controls")
      .doesNotExist("no zoom controls when zoom disabled");
    assert
      .dom(".d-ic__fullscreen-btn")
      .doesNotExist("no fullscreen button when fullscreen disabled");
  });

  test("labels render with custom text and position modifier", async function (assert) {
    // showLabels must be null (not undefined) so the component falls back to
    // settings.default_show_labels (true); undefined is treated as falsy and
    // hides labels.
    const data = compareData({
      showLabels: null,
      beforeLabel: "Old",
      afterLabel: "New",
      labelPosition: "start",
    });
    await render(<template><ImageCompare @data={{data}} /></template>);

    assert.dom(".d-ic__label--before").hasText("Old", "before label text");
    assert.dom(".d-ic__label--after").hasText("New", "after label text");
    assert
      .dom(".d-ic")
      .hasClass("d-ic--labels-start", "label position modifier applied");
  });

  test("showLabels: false hides both labels", async function (assert) {
    const data = compareData({ showLabels: false });
    await render(<template><ImageCompare @data={{data}} /></template>);

    assert.dom(".d-ic__label--before").doesNotExist("no before label");
    assert.dom(".d-ic__label--after").doesNotExist("no after label");
  });

  test("caption renders only when provided", async function (assert) {
    const data = compareData({ caption: "A test caption" });
    await render(<template><ImageCompare @data={{data}} /></template>);
    assert
      .dom("figcaption.d-ic__caption")
      .hasText("A test caption", "caption renders");

    const bare = compareData();
    await render(<template><ImageCompare @data={{bare}} /></template>);
    assert
      .dom("figcaption.d-ic__caption")
      .doesNotExist("no caption element when unset");
  });

  test("handle styles add their modifier class and knob", async function (assert) {
    const circle = compareData({ handleStyle: "circle" });
    await render(<template><ImageCompare @data={{circle}} /></template>);
    assert.dom(".d-ic").hasClass("d-ic--handle-circle", "circle modifier");
    assert.dom(".d-ic__circle").exists("circle knob renders");

    const grabber = compareData({ handleStyle: "grabber" });
    await render(<template><ImageCompare @data={{grabber}} /></template>);
    assert.dom(".d-ic").hasClass("d-ic--handle-grabber", "grabber modifier");
    assert.dom(".d-ic__grabber").exists("grabber knob renders");
  });

  test("fullscreen opens a dialog portal, Escape closes and restores focus", async function (assert) {
    const data = compareData();
    await render(<template><ImageCompare @data={{data}} /></template>);

    find(".d-ic__fullscreen-btn").focus();
    await click(".d-ic__fullscreen-btn");

    const overlay = document.body.querySelector(".d-ic-fs");
    assert.dom(overlay).exists("overlay renders in the body portal");
    assert.dom(overlay).hasAttribute("role", "dialog", "overlay is a dialog");
    assert
      .dom(".d-ic__viewport", overlay)
      .exists("nested slider viewport renders");

    await triggerKeyEvent(document, "keydown", "Escape");

    assert
      .dom(document.body.querySelector(".d-ic-fs"))
      .doesNotExist("Escape closes the overlay");
    assert.strictEqual(
      document.activeElement,
      find(".d-ic__fullscreen-btn"),
      "focus returns to the trigger"
    );
  });
});

import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const TWO_IMAGES = [
  "[wrap=image-compare]",
  "![before](https://example.com/a.png)",
  "![after](https://example.com/b.png)",
  "[/wrap]",
].join("\n");

const ONE_IMAGE = [
  "[wrap=image-compare]",
  "![only](https://example.com/a.png)",
  "[/wrap]",
].join("\n");

async function compose(content) {
  await visit("/latest");
  await click("#create-topic");

  const categoryChooser = selectKit(".category-chooser");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(2);

  await fillIn(".d-editor-input", content);
}

acceptance("Image Comparison Slider", function (needs) {
  needs.user();

  test("renders the slider in the cooked preview", async function (assert) {
    await compose(TWO_IMAGES);

    assert
      .dom(".d-editor-preview .d-ic__viewport")
      .exists("the comparison slider is rendered");
    assert
      .dom(".d-editor-preview .d-ic__image--before")
      .exists("the before image is rendered");
    assert
      .dom(".d-editor-preview .d-ic__image--after")
      .exists("the after image is rendered");
    assert
      .dom(".d-editor-preview .d-ic__handle")
      .exists("the drag handle is rendered");
  });

  test("falls back to plain content with fewer than two images", async function (assert) {
    await compose(ONE_IMAGE);

    assert
      .dom(".d-editor-preview .d-ic")
      .doesNotExist("no slider is rendered with a single image");
    assert
      .dom(".d-editor-preview img")
      .exists("the single image still renders normally");
  });
});

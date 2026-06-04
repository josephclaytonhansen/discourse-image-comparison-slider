import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

const NEW_FORMAT = [
  "[wrap=image-compare]",
  "![before](https://example.com/a.png)",
  "![after](https://example.com/b.png)",
  "[/wrap]",
].join("\n");

module("Integration | Rich Editor | Image compare", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.rich_editor = true;
  });

  test("round-trips the wrap format through the rich editor", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, NEW_FORMAT);
    const markdown = editorClass.value;

    assert.true(markdown.includes("[wrap=image-compare"), "keeps the wrap tag");
    assert.true(markdown.includes("a.png"), "keeps the before image");
    assert.true(markdown.includes("b.png"), "keeps the after image");
  });
});

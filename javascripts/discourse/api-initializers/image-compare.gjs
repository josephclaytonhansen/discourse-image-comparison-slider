import { action } from "@ember/object";
import { setOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";
import ImageCompare from "../components/image-compare";
import { legacyOrientation, normalizeConfig } from "../lib/image-compare/utils";
import richEditorExtension from "../lib/rich-editor-extension";

class ImageCompareInit {
  @service previewState;

  constructor(owner, api) {
    setOwner(this, owner);

    api.decorateCookedElement((element, helper) =>
      this.processImageCompare(element, helper)
    );

    api.registerRichEditorExtension(richEditorExtension);

    api.modifyClass(
      "component:d-editor",
      (SuperClass) =>
        class extends SuperClass {
          @service previewState;

          @action
          async toggleRichEditor() {
            super.toggleRichEditor();
            next(() => {
              this.previewState.reset();
            });
          }
        }
    );

    const locale = window.I18n.fallbackLocale || "en";
    window.I18n.translations[locale].js.composer ??= {};
    window.I18n.translations[locale].js.composer.image_compare_sample = "";

    api.onToolbarCreate((toolbar) => {
      toolbar.addButton({
        trimLeading: true,
        id: "image-comparison-slider",
        group: "insertions",
        icon: "ict-image-compare",
        title: themePrefix("image_compare.composer.insert_slider"),
        action: (toolbarEvent) => {
          if (toolbarEvent.commands) {
            toolbarEvent.commands.insertImageCompare();
          } else {
            toolbarEvent.applySurround(
              "[wrap=image-compare]\n",
              "\n[/wrap]",
              "image_compare_sample",
              { multiline: false }
            );
          }
        },
      });
    });
  }

  renderSlider(
    wrap,
    config,
    helper,
    { isPreview = false, wrapIndex = 0 } = {}
  ) {
    const parsedConfig = normalizeConfig(config);
    const images = this.extractImages(wrap);

    if (!images.before?.previewSrc || !images.after?.previewSrc) {
      wrap.replaceWith(...wrap.childNodes);
      return;
    }

    const container = document.createElement("div");
    container.classList.add("d-ic-container");

    helper.renderGlimmer(container, ImageCompare, {
      ...parsedConfig,
      images,
      isPreview,
      wrapIndex,
      uiState: isPreview ? this.previewState.stateFor(wrapIndex) : null,
    });

    wrap.replaceWith(container);
  }

  processImageCompare(element, helper) {
    const isPreview = !helper.model;
    let wrapIndex = 0;

    // New + legacy formats
    element
      .querySelectorAll(
        "[data-wrap=image-compare], div[data-image-comparison-slider]"
      )
      .forEach((wrap) => {
        const isLegacy = wrap.matches("[data-image-comparison-slider]");
        const config = isLegacy
          ? this.extractLegacyConfig(wrap)
          : this.extractConfig(wrap);

        this.renderSlider(wrap, config, helper, { isPreview, wrapIndex });
        wrapIndex++;
      });
  }

  extractImages(element) {
    const imgs = element.querySelectorAll("img:not(.emoji)");

    return {
      before: this.extractSlot(imgs[0], "before"),
      after: this.extractSlot(imgs[1], "after"),
    };
  }

  extractSlot(imageNode, slot) {
    if (!imageNode) {
      return null;
    }

    const previewSrc = imageNode.getAttribute("src") ?? null;
    const alt = imageNode.getAttribute("alt") ?? "";
    const anchor = imageNode.closest("a.lightbox");

    if (!anchor) {
      return {
        previewSrc,
        alt,
        fullSrc: null,
        previewMarkup: null,
        fullMarkup: null,
      };
    }

    const source = anchor.closest(".lightbox-wrapper") ?? anchor;
    imageNode.classList.remove("lightbox");
    imageNode.classList.add("d-ic__image", `d-ic__image--${slot}`);
    imageNode.setAttribute("draggable", "false");

    const previewMarkup = source.outerHTML;
    const fullSrc = anchor.getAttribute("href") || null;
    let fullMarkup = previewMarkup;

    if (fullSrc) {
      const previousSrc = imageNode.getAttribute("src");
      const previousSrcset = imageNode.getAttribute("srcset");

      imageNode.setAttribute("src", fullSrc);
      imageNode.removeAttribute("srcset");
      fullMarkup = source.outerHTML;
      imageNode.setAttribute("src", previousSrc);

      if (previousSrcset !== null) {
        imageNode.setAttribute("srcset", previousSrcset);
      }
    }

    return { previewSrc, alt, fullSrc, previewMarkup, fullMarkup };
  }

  extractConfig(element) {
    const config = {};

    for (const [key, value] of Object.entries(element.dataset)) {
      if (key !== "wrap" && value.trim() !== "") {
        config[key] = value;
      }
    }

    return config;
  }

  extractLegacyConfig(element) {
    const orientation = legacyOrientation({
      vertical: element.hasAttribute("data-direction-vertical"),
      horizontal: element.hasAttribute("data-direction-horizontal"),
    });

    return orientation ? { orientation } : {};
  }
}

export default {
  name: "discourse-image-compare",

  initialize(owner) {
    withPluginApi((api) => {
      this.instance = new ImageCompareInit(owner, api);
    });
  },

  teardown() {
    this.instance = null;
  },
};

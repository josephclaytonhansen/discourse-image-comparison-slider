import { apiInitializer } from "discourse/lib/api";
import I18n from "discourse-i18n";

export default apiInitializer("1.8.0", (api) => {
  function extractImages(html) {
    const imgs = html.querySelectorAll("img");
    var length = [...imgs].length;
    if (length > 0) {
      return [imgs[0].src, imgs[1].src];
    } else {
      return ["No image found", "No image found"];
    }
  }

  function stackImages(imgs, d) {
    console.log(imgs[0]);
    var left = ["<img slot='first' src='", imgs[0], "'/>"].join("");
    var right = ["<img slot='second' src='", imgs[1], "'/>"].join("");
    var direction = d;
    if (settings.handle_arrow_style == "solid") {
      right =
        right +
        '<svg slot="handle" class = "grab-handle" style = "cursor:grab" xmlns="http://www.w3.org/2000/svg" width="70" viewBox="-8 -3 16 6"><path stroke="#000" d="M -5 -2 L -7 0 L -5 2 M -5 -2 L -5 2 M 5 -2 L 7 0 L 5 2 M 5 -2 L 5 2" stroke-width="1" fill="#fff" vector-effect="non-scaling-stroke"></path></svg>';
    }
    return [
      "<img-comparison-slider class = 'colored-slider' direction = '",
      direction,
      "'>",
      left,
      right,
      "</img-comparison-slider>",
    ].join("");
  }

  function componentPrep(cooked) {
    cooked
      .querySelectorAll("div[data-image-comparison-slider]")
      .forEach((slider) => {
        let imgs = extractImages(slider);
        let finalHTML = stackImages(imgs, settings.default_direction);
        slider.innerHTML = finalHTML;
      });
    cooked
      .querySelectorAll(
        "div[data-image-comparison-slider][data-direction-horizontal]"
      )
      .forEach((slider) => {
        let imgs = extractImages(slider);
        let finalHTML = stackImages(imgs, "horizontal");
        slider.innerHTML = finalHTML;
      });
    cooked
      .querySelectorAll(
        "div[data-image-comparison-slider][data-direction-vertical]"
      )
      .forEach((slider) => {
        let imgs = extractImages(slider);
        let finalHTML = stackImages(imgs, "vertical");
        slider.innerHTML = finalHTML;
      });
  }

  let translations = I18n.translations[I18n.currentLocale()].js;

  if (!translations) {
    translations = {};
  }
  if (!translations.composer) {
    translations.composer = {};
  }
  translations.button_text = settings.button_text;
  translations.composer.add_images_prompt = settings.add_images_prompt;

  api.decorateCookedElement(componentPrep, {
    onlyStream: false,
    id: "image-comparison-slider",
  });

  api.onToolbarCreate(function (toolbar) {
    toolbar.addButton({
      trimLeading: true,
      id: "image-comparison-slider",
      group: "insertions",
      icon: settings.button_icon,
      title: "button_text",
      perform: (e) =>
        e.applySurround(
          [
            "<div data-image-comparison-slider data-direction-",
            settings.default_direction,
            ">\n\n",
          ].join(""),
          "\n\n</div>",
          "add_images_prompt",
          { multiline: false }
        ),
    });
  });
});

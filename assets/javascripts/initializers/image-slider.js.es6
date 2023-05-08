import { withPluginApi, decorateCooked, onToolbarCreate } from 'discourse/lib/plugin-api';
export default {
  name: "image-slider",
  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    const sliderSettings = {
      amount: parseInt(siteSettings.default_amount),
      direction: siteSettings.default_direction,
      prompt: siteSettings.add_slider_images_prompt
    }

    const sliderWithSettings = ($elem) => {
      $('.image-comparison-slider', $elem).removeClass('image-comparison-slider').addClass('discourse-image-comparison-slider');
    }

    const initializer = (api) => api.decorateCooked(sliderWithSettings);

    withPluginApi('0.5', initializer, { noApi: () => decorateCooked(container, sliderWithSettings) });


    const initializer_button = (api) => api.onToolbarCreate(function(toolbar) {
      toolbar.addButton({
        trimLeading: true,
        id: "image-comparison-slider",
        group: "insertions",
        icon: "bolt",
        title: "Image comparison slider",
        perform: e => e.applySurround(
          "<div class = 'image-comparison-slider'>\n\n",
          "\n\n</div>",
          siteSettings.prompt,
           { multiline: false }
        )
      });
    });
    withPluginApi('0.5', initializer_button);


  }
};

# frozen_string_literal: true

module PageObjects
  module Components
    class ImageCompare < PageObjects::Components::Base
      def has_slider?(within: nil)
        selector = ".d-ic .d-ic__handle[role='slider']"
        selector = "#{within} #{selector}" if within
        page.has_css?(selector)
      end

      def has_labels?
        page.has_css?(".d-ic__label--before") && page.has_css?(".d-ic__label--after")
      end

      def has_clips?
        page.has_css?(".d-ic__clip--before") && page.has_css?(".d-ic__clip--after")
      end

      def has_zoom_controls?
        page.has_css?(".d-ic__zoom-controls", visible: :all)
      end

      def has_no_zoom_controls?
        page.has_no_css?(".d-ic__zoom-controls", visible: :all)
      end

      def has_fullscreen_button?
        page.has_css?(".d-ic__fullscreen-btn", visible: :all)
      end

      def has_no_fullscreen_button?
        page.has_no_css?(".d-ic__fullscreen-btn", visible: :all)
      end

      def open_fullscreen
        find(".d-ic__viewport").hover
        find(".d-ic__fullscreen-btn").click
      end

      def has_fullscreen_overlay?
        page.has_css?(".d-ic-fs .d-ic__viewport")
      end

      def has_no_fullscreen_overlay?
        page.has_no_css?(".d-ic-fs")
      end

      def close_fullscreen_with_escape
        send_keys(:escape)
      end
    end
  end
end

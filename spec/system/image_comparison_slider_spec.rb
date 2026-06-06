# frozen_string_literal: true

require_relative "page_objects/components/image_compare"

RSpec.describe "Image Comparison Slider", system: true do
  let!(:theme) { upload_theme_component }

  fab!(:current_user, :user)
  fab!(:topic)
  fab!(:upload_1) { Fabricate(:image_upload, width: 800, height: 600) }
  fab!(:upload_2) { Fabricate(:image_upload, width: 800, height: 600) }

  fab!(:post) { Fabricate(:post, topic: topic, raw: <<~MD) }
      [wrap=image-compare]
      ![before](#{upload_1.url})
      ![after](#{upload_2.url})
      [/wrap]
    MD

  let(:image_compare) { PageObjects::Components::ImageCompare.new }

  before do
    SiteSetting.create_thumbnails = true
    sign_in(current_user)
  end

  def cook_post(post)
    cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
    cpp.post_process
    post.update!(cooked: cpp.html)
  end

  before { cook_post(post) }

  it "renders the slider with handle, labels, and controls" do
    visit(topic.url)

    expect(image_compare).to have_slider
    expect(image_compare).to have_clips
    expect(image_compare).to have_labels
    # Controls are opacity:0 until hovered; assert presence in DOM regardless of opacity
    expect(image_compare).to have_zoom_controls
    expect(image_compare).to have_fullscreen_button
  end

  it "hides zoom and fullscreen controls when their settings are disabled" do
    theme.update_setting(:enable_zoom, false)
    theme.update_setting(:enable_fullscreen, false)
    theme.update_setting(:enable_lightbox, false)
    theme.save!

    visit(topic.url)

    expect(image_compare).to have_slider
    # With zoom, fullscreen, and lightbox all off, showControlsBar is false — no controls bar in DOM
    expect(image_compare).to have_no_zoom_controls
    expect(image_compare).to have_no_fullscreen_button
  end

  it "opens and closes the fullscreen overlay" do
    visit(topic.url)

    image_compare.open_fullscreen
    expect(image_compare).to have_fullscreen_overlay

    image_compare.close_fullscreen_with_escape
    expect(image_compare).to have_no_fullscreen_overlay
  end

  context "with the legacy markup format" do
    fab!(:legacy_post) { Fabricate(:post, topic: topic, raw: <<~MD) }
        [wrap=compare image-comparison-slider=true]
        ![before](#{upload_1.url})
        ![after](#{upload_2.url})
        [/wrap]
      MD

    before { cook_post(legacy_post) }

    it "still renders a slider" do
      visit(topic.url)

      expect(image_compare).to have_slider(within: "#post_#{legacy_post.post_number}")
    end
  end

  context "with allowed_groups restricted" do
    fab!(:allowed_group, :group)
    fab!(:allowed_user) { Fabricate(:user, groups: [allowed_group]) }

    let(:topic_page) { PageObjects::Pages::Topic.new }
    let(:composer) { PageObjects::Components::Composer.new }

    before do
      theme.update_setting(:allowed_groups, allowed_group.id.to_s)
      theme.save!
    end

    it "shows the composer button only to members of the allowed group" do
      sign_in(allowed_user)
      visit(topic.url)
      topic_page.click_reply_button
      expect(composer).to be_opened
      expect(page).to have_css(".d-editor-button-bar button.image-comparison-slider")
    end

    it "hides the composer button from non-members" do
      sign_in(current_user)
      visit(topic.url)
      topic_page.click_reply_button
      expect(composer).to be_opened
      expect(page).to have_no_css(".d-editor-button-bar button.image-comparison-slider")
    end
  end
end

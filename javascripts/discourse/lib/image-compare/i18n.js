import { i18n } from "discourse-i18n";

export const settingsI18n = (key) =>
  i18n(themePrefix(`image_compare.composer.settings.${key}`));

export const composerI18n = (key) =>
  i18n(themePrefix(`image_compare.composer.${key}`));

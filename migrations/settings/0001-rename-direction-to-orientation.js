export default function migrate(settings) {
  if (settings.has("default_direction")) {
    settings.set("default_orientation", settings.get("default_direction"));
    settings.delete("default_direction");
  }

  return settings;
}

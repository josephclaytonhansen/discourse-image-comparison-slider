import { module, test } from "qunit";
import migrate from "../../../../migrations/settings/0001-rename-direction-to-orientation";

module(
  "Unit | Migrations | Settings | 0001-rename-direction-to-orientation",
  function () {
    test("renames default_direction to default_orientation", function (assert) {
      const settings = new Map(
        Object.entries({
          default_direction: "vertical",
        })
      );

      const result = migrate(settings);

      assert.deepEqual(
        Array.from(result),
        Array.from(
          new Map(Object.entries({ default_orientation: "vertical" }))
        ),
        "default_direction is renamed to default_orientation"
      );
    });

    test("preserves other settings untouched", function (assert) {
      const settings = new Map(
        Object.entries({
          default_direction: "horizontal",
          default_position: 50,
        })
      );

      const result = migrate(settings);

      assert.deepEqual(
        Array.from(result),
        Array.from(
          new Map(
            Object.entries({
              default_position: 50,
              default_orientation: "horizontal",
            })
          )
        ),
        "unrelated settings are preserved alongside the rename"
      );
    });

    test("no-op when default_direction is absent", function (assert) {
      const settings = new Map(
        Object.entries({
          default_orientation: "vertical",
        })
      );

      const result = migrate(settings);

      assert.deepEqual(
        Array.from(result),
        Array.from(settings),
        "settings are unchanged when default_direction is absent"
      );
    });

    test("no-op on empty settings", function (assert) {
      const settings = new Map(Object.entries({}));
      const result = migrate(settings);
      assert.deepEqual(
        Array.from(result),
        Array.from(settings),
        "empty settings stay empty"
      );
    });
  }
);

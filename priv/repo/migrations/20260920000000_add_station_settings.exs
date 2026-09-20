defmodule Cafe.Repo.Migrations.AddStationSettings do
  use Ecto.Migration

  def up do
    alter table(:stations) do
      add :shortcut, :string
      add :position, :integer, null: false, default: 0
      add :image_url, :string
      add :effect, :string, null: false, default: "none"
      add :seed_key, :string
    end

    flush()

    execute("""
    UPDATE stations AS s
    SET name = replace(s.name, '_', ' '),
        shortcut = settings.shortcut, position = settings.position,
        image_url = settings.image_url, effect = settings.effect, seed_key = settings.name
    FROM (VALUES
      ('spring', 's', 0, '/images/themes/seasons/spring/thumbs/1.webp', 'spring'),
      ('summer', 'u', 1, '/images/themes/seasons/summer/thumbs/1.webp', 'summer'),
      ('autumn', 'a', 2, '/images/themes/seasons/autumn/thumbs/1.webp', 'autumn'),
      ('winter', 'w', 3, '/images/themes/seasons/winter/thumbs/1.webp', 'winter'),
      ('blade_runner', 'b', 4, '/images/themes/vibes/blade_runner/thumbs/1.webp', 'none'),
      ('christmas', 'c', 5, '/images/themes/vibes/christmas/thumbs/1.webp', 'none'),
      ('cozy', 'o', 6, '/images/themes/vibes/cozy/thumbs/1.webp', 'none'),
      ('locked_in', 'e', 7, '/images/themes/vibes/locked_in/thumbs/1.webp', 'none'),
      ('morning_coffee', 'r', 8, '/images/themes/vibes/morning_coffee/thumbs/1.webp', 'none'),
      ('rainy_day', 'i', 9, '/images/themes/vibes/rainy_day/thumbs/1.webp', 'none')
    ) AS settings(name, shortcut, position, image_url, effect)
    WHERE s.name = settings.name
    """)

    create unique_index(:stations, [:shortcut])
    create unique_index(:stations, [:seed_key])
  end

  def down do
    alter table(:stations) do
      remove :shortcut
      remove :position
      remove :image_url
      remove :effect
      remove :seed_key
    end
  end
end

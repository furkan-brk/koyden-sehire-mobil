ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS icon_name  VARCHAR(64) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS color_hex  VARCHAR(7)  NOT NULL DEFAULT '#4CAF50';

-- Seed icon_name and color_hex for top-level categories
UPDATE categories SET icon_name = 'fruit',       color_hex = '#E91E63' WHERE slug = 'meyve';
UPDATE categories SET icon_name = 'vegetables',  color_hex = '#4CAF50' WHERE slug = 'sebze';
UPDATE categories SET icon_name = 'grain',       color_hex = '#795548' WHERE slug = 'baklagil-tahil';
UPDATE categories SET icon_name = 'dairy',       color_hex = '#03A9F4' WHERE slug = 'sut-urunleri';
UPDATE categories SET icon_name = 'honey',       color_hex = '#FFC107' WHERE slug = 'bal-ari-urunleri';
UPDATE categories SET icon_name = 'eggs',        color_hex = '#FF9800' WHERE slug = 'yumurta';
UPDATE categories SET icon_name = 'olive',       color_hex = '#8BC34A' WHERE slug = 'zeytin-zeytinyagi';
UPDATE categories SET icon_name = 'nuts',        color_hex = '#FF5722' WHERE slug = 'kuruyemis';
UPDATE categories SET icon_name = 'natural',     color_hex = '#009688' WHERE slug = 'dogal-urunler';

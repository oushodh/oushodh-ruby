# frozen_string_literal: true

module Oushodh
  # One medicine: one brand in one strength and dosage form.
  class Medicine < Model
    fields :id, :uuid, :brand, :category, :product_name, :product_image, :images, :unit, :size, :price,
           :price_per, :price_source, :description_en, :description_bn, :dosage_form, :strength,
           :generic_name, :manufacturer, :source_url, :last_updated, :dgda_listed, :medicine_type,
           unit_prices: [UnitPrice], prices: Prices
  end
end

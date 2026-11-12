# frozen_string_literal: true

module Oushodh
  # A JSON object from the API. It keeps the whole parsed hash, so fields the API adds later stay readable
  # with `[]` and `to_h`. Each documented field also has a reader.
  class Model
    def self.fields(*names, **nested)
      names.each do |name|
        define_method(name) { @data[name.to_s] }
      end

      nested.each do |name, type|
        define_method(name) { Model.wrap(@data[name.to_s], type) }
      end
    end

    def self.wrap(value, type)
      if value.nil?
        return nil
      end

      if type.is_a?(Array)
        return value.map { |item| type.first.new(item) }
      end

      type.new(value)
    end

    def initialize(data)
      @data = data
    end

    def [](key)
      @data[key.to_s]
    end

    def dig(key, *rest)
      @data.dig(key.to_s, *rest)
    end

    def to_h
      @data
    end

    def ==(other)
      other.is_a?(self.class) && other.to_h == @data
    end

    alias eql? ==

    def hash
      [self.class, @data].hash
    end

    def inspect
      "#<#{self.class.name} #{@data.inspect}>"
    end
  end

  # One `unit_prices` entry.
  class UnitPrice < Model
    fields :size, :price
  end

  # `prices.unit`.
  class UnitAmount < Model
    fields :amount, :source
  end

  # One `prices.sizes` entry.
  class SizeAmount < Model
    fields :size, :amount, :source
  end

  # `prices.strip`.
  class StripAmount < Model
    fields :amount, :units, :source
  end

  # One `prices.packs` entry.
  class PackAmount < Model
    fields :amount, :units, :label, :source
  end

  # Every MRP the sources state for a medicine.
  class Prices < Model
    fields :currency, unit: UnitAmount, sizes: [SizeAmount], strip: StripAmount, packs: [PackAmount]
  end

  # One medicine: one brand in one strength and dosage form.
  class Medicine < Model
    fields :id, :uuid, :brand, :category, :product_name, :product_image, :images, :unit, :size, :price,
           :price_per, :price_source, :description_en, :description_bn, :dosage_form, :strength,
           :generic_name, :manufacturer, :source_url, :last_updated, :dgda_listed, :medicine_type,
           unit_prices: [UnitPrice], prices: Prices
  end

  # The medical text of a medicine, as its source wrote it.
  class Monograph < Model
    fields :source, :indications, :composition, :pharmacology, :dosage, :interactions, :contraindications,
           :side_effects, :pregnancy_lactation, :precautions, :overdose, :storage
  end

  # One medicine, with its medical text.
  class MedicineDetail < Medicine
    fields monograph: Monograph
  end

  # One page of medicines.
  class Page < Model
    fields :next, :total, items: [Medicine]
  end

  # The best matches for a search.
  class SearchResult < Model
    fields :total, items: [Medicine]
  end

  # The account the key belongs to.
  class Meta < Model
    fields :client, :id_profile, :medicines, :last_import
  end
end

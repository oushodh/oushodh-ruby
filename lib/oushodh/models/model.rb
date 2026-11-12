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
end

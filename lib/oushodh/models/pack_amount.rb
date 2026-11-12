# frozen_string_literal: true

module Oushodh
  # One `prices.packs` entry.
  class PackAmount < Model
    fields :amount, :units, :label, :source
  end
end

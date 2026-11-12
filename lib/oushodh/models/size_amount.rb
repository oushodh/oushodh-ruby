# frozen_string_literal: true

module Oushodh
  # One `prices.sizes` entry.
  class SizeAmount < Model
    fields :size, :amount, :source
  end
end

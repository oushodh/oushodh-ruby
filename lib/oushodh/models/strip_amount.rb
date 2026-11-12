# frozen_string_literal: true

module Oushodh
  # `prices.strip`.
  class StripAmount < Model
    fields :amount, :units, :source
  end
end

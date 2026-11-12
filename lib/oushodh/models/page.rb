# frozen_string_literal: true

module Oushodh
  # One page of medicines.
  class Page < Model
    fields :next, :total, items: [Medicine]
  end
end

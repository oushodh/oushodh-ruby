# frozen_string_literal: true

module Oushodh
  # Every MRP the sources state for a medicine.
  class Prices < Model
    fields :currency, unit: UnitAmount, sizes: [SizeAmount], strip: StripAmount, packs: [PackAmount]
  end
end

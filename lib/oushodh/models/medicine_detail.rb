# frozen_string_literal: true

module Oushodh
  # One medicine, with its medical text.
  class MedicineDetail < Medicine
    fields monograph: Monograph
  end
end

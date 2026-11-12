# frozen_string_literal: true

module Oushodh
  # The medical text of a medicine, as its source wrote it.
  class Monograph < Model
    fields :source, :indications, :composition, :pharmacology, :dosage, :interactions, :contraindications,
           :side_effects, :pregnancy_lactation, :precautions, :overdose, :storage
  end
end

# frozen_string_literal: true

module Oushodh
  # The account the key belongs to.
  class Meta < Model
    fields :client, :id_profile, :medicines, :last_import
  end
end

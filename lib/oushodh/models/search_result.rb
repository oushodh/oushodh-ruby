# frozen_string_literal: true

module Oushodh
  # The best matches for a search.
  class SearchResult < Model
    fields :total, items: [Medicine]
  end
end

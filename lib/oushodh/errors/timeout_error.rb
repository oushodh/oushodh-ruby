# frozen_string_literal: true

module Oushodh
  # No answer came back in time.
  class TimeoutError < ConnectionError; end
end

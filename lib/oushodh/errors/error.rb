# frozen_string_literal: true

module Oushodh
  # The base of every error the SDK raises. `status` is the HTTP status and `code` the API's error code.
  # Both are nil when no answer came back. Match on `code` or the class, never on `message`.
  class Error < StandardError
    attr_reader :status, :code

    def initialize(message, status: nil, code: nil)
      super(message)
      @status = status
      @code = code
    end
  end
end

# frozen_string_literal: true

module Oushodh
  # 429 `rate_limited` or `quota_exceeded`. `retry_after` is in seconds.
  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message, status: nil, code: nil, retry_after: nil)
      super(message, status: status, code: code)
      @retry_after = retry_after
    end
  end
end

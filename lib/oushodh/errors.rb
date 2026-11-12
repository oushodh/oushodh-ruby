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

  # 400 `bad_request`.
  class BadRequestError < Error; end

  # 401 `unauthorized`: no key, an unknown key or a revoked key.
  class AuthenticationError < Error; end

  # 403 `plan_expired` or `plan_limit`.
  class PermissionDeniedError < Error; end

  # 404 `not_found`.
  class NotFoundError < Error; end

  # 429 `rate_limited` or `quota_exceeded`. `retry_after` is in seconds.
  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message, status: nil, code: nil, retry_after: nil)
      super(message, status: status, code: code)
      @retry_after = retry_after
    end
  end

  # 5xx, such as `internal`.
  class InternalServerError < Error; end

  # No answer came back: the network failed.
  class ConnectionError < Error; end

  # No answer came back in time.
  class TimeoutError < ConnectionError; end
end

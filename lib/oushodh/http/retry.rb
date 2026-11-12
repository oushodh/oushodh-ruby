# frozen_string_literal: true

module Oushodh
  # When to try a failed request again, and how long to wait first.
  module Retry
    module_function

    # Seconds to wait before the next try, or nil to raise the error now.
    def delay(error, attempt, max_retries)
      if attempt >= max_retries
        return nil
      end

      # quota_exceeded waits until next month, so only rate_limited is retried.
      if error.is_a?(RateLimitError)
        return error.code == "rate_limited" ? error.retry_after || backoff(attempt) : nil
      end

      if error.is_a?(InternalServerError) || error.is_a?(ConnectionError)
        return backoff(attempt)
      end

      nil
    end

    def backoff(attempt)
      [0.5 * (2**attempt), 8.0].min * rand(0.5..1.0)
    end
  end
end

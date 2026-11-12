# frozen_string_literal: true

module Oushodh
  # 401 `unauthorized`: no key, an unknown key or a revoked key.
  class AuthenticationError < Error; end
end

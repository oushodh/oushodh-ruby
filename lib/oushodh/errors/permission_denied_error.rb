# frozen_string_literal: true

module Oushodh
  # 403 `plan_expired` or `plan_limit`.
  class PermissionDeniedError < Error; end
end
